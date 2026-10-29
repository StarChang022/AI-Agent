require "image_processing/vips"

module Api
  # 憑證 OCR endpoints。見 docs/OCR辨識規格.md。
  # - POST /api/ocr/recognize  上傳 1–5 張同一張憑證的照片 / PDF，回合併結果 + 衝突清單
  # - GET  /api/ocr/quota      查本公司剩餘次數；管理員與員工都可查（員工代墊款表單要顯示）
  #
  # 錯誤 payload：{ code, message, quota? }（quota 在 429 與 422 附上；422 有扣次，前端用它更新剩餘次數）。
  class OcrController < ApplicationController
    # Document AI 不收 HEIC（iPhone 預設格式），送出前先轉成 JPEG。
    ALLOWED_MIMES = %w[image/jpeg image/png image/webp image/heic application/pdf].freeze
    HEIC_MIMES    = %w[image/heic image/heif].freeze
    # 表單上看得到的欄位；至少抽到一個（或有品項）才算辨識出內容
    VISIBLE_FIELDS = %i[incurred_at counterparty_name counterparty_tax_id invoice_prefix invoice_digits
                        pre_tax_amt tax_amt amount].freeze

    # POST /api/ocr/recognize   multipart: files[], role
    #
    # 檢查順序：role → 張數 → 格式 → 大小 → GCP 設定 → 配額 → 逐檔辨識。
    # 只有 Document AI 成功回傳的檔案才扣次（按實際頁數）；任一檔遇到 503 類錯誤就整個回 503、不扣次。
    def recognize
      role = params[:role].to_s
      unless Ocr::ReceiptTextExtractor::ROLES.include?(role)
        return render_error(:bad_request, "invalid_role", "role 必須是 expense / reimbursement / income")
      end

      files = Array(params[:files]).select { |f| f.is_a?(ActionDispatch::Http::UploadedFile) }
      if files.empty?
        return render_error(:bad_request, "invalid_file_type", "請至少上傳 1 個檔案")
      end
      if files.size > ReceiptAttachmentValidation::MAX_COUNT
        return render_error(:bad_request, "too_many_files",
                            "最多 #{ReceiptAttachmentValidation::MAX_COUNT} 個檔案（目前 #{files.size} 個）")
      end

      mimes = files.map { |f| detect_mime(f) }
      if (index = mimes.index { |m| !ALLOWED_MIMES.include?(m) })
        return render_error(:bad_request, "invalid_file_type",
                            "第 #{index + 1} 個檔案格式不支援（只接受 JPG／PNG／WEBP／HEIC／PDF）")
      end
      if (index = files.index { |f| f.size > ReceiptAttachmentValidation::MAX_FILE_BYTES })
        return render_error(:payload_too_large, "file_too_large",
                            "第 #{index + 1} 個檔案超過 #{ReceiptAttachmentValidation::MAX_FILE_BYTES / 1024 / 1024}MB 上限")
      end

      client = Ocr::DocumentAiClient.from_env
      quota  = Ocr::Quota.new(current_user.company)
      quota.ensure_available!(files.size)

      results  = []
      warnings = []
      pages    = 0

      files.each_with_index do |file, i|
        bytes, mime = document_payload(file, mimes[i])
        invoices = scan_invoices(bytes, mime, i)
        document = client.process(bytes, mime)
        pages += [ Array(document["pages"]).size, 1 ].max

        result = Ocr::InvoiceQr.apply(extract_fields(document, role, i), invoices,
                                      role: role, source_index: i, document: document)
        if result && recognized?(result)
          results << result
        else
          warnings << "第 #{i + 1} 個檔案未辨識出內容"
        end
      rescue Ocr::DocumentAiClient::InvalidDocument, Vips::Error => e
        Rails.logger.info("[ocr] file #{i} rejected: #{e.message}")
        warnings << "第 #{i + 1} 個檔案無法辨識，已略過"
      end

      used = quota.consume!(pages)

      if results.empty?
        return render_error(:unprocessable_content, "ocr_no_result", "無法辨識憑證內容，請改手動輸入",
                            quota: quota.snapshot(used: used))
      end

      merged = Ocr::ResultMerger.call(results)
      render json: merged.merge(
        warnings: warnings + merged[:warnings],
        quota:    quota.snapshot(used: used)
      )
    rescue Ocr::DocumentAiClient::Unavailable => e
      Rails.logger.warn("[ocr] unavailable: #{e.message}")
      render_error(:service_unavailable, "ocr_unavailable", "OCR 服務暫時無法使用，請改手動輸入")
    rescue Ocr::Quota::Exhausted
      render_error(:too_many_requests, "quota_exhausted", "本月 OCR 辨識次數已用完",
                   quota: quota.snapshot)
    end

    # GET /api/ocr/quota
    def quota
      quota = Ocr::Quota.new(current_user.company)
      quota.refresh!
      render json: quota
    end

    private

    # 只看檔案內容判斷格式，不採信副檔名與瀏覽器送來的 Content-Type（避免改副檔名繞過）。
    def detect_mime(file)
      mime = Marcel::MimeType.for(Pathname(file.tempfile.path))
      HEIC_MIMES.include?(mime) ? "image/heic" : mime
    end

    # HEIC 轉檔前先看檔頭的寬 × 高，超過像素上限就當作檔案無法辨識（不送 Google、不扣次）。
    def document_payload(file, mime)
      if mime == "image/heic"
        image = Vips::Image.new_from_file(file.tempfile.path)
        if image.width * image.height > Ocr::QrScanner::MAX_PIXELS
          raise Ocr::DocumentAiClient::InvalidDocument, "image too large"
        end
        jpeg = ImageProcessing::Vips.source(image).convert("jpg").call
        [ File.binread(jpeg.path), "image/jpeg" ]
      else
        [ File.binread(file.tempfile.path), mime ]
      end
    end

    # 抽欄位出任何錯（含正規表達式逾時）都當作這個檔案沒有結果；Google 已計費，頁數照算進扣次。
    # log 只記錯誤類別與訊息，不記全文與統編。
    def extract_fields(document, role, index)
      Ocr::ReceiptTextExtractor.call(document, role: role, source_index: index)
    rescue StandardError => e
      Rails.logger.error("[ocr] file #{index} extract failed: #{e.class}: #{e.message}")
      nil
    end

    # 電子發票 QR（docs/OCR辨識規格.md §3.2）：解不出來或出任何錯都當作沒有 QR，不影響辨識。
    # log 只記錯誤類別與訊息，不記 QR 內容。
    def scan_invoices(bytes, mime, index)
      Ocr::InvoiceQr.call(Ocr::QrScanner.call(bytes, mime))
    rescue StandardError => e
      Rails.logger.info("[ocr] file #{index} qr parse failed: #{e.class}: #{e.message}")
      []
    end

    # documentType / taxRate 是推導值、我方名稱 / 統編表單沒有欄位，都不算「辨識出內容」。
    # 有多張發票的檔案，QR 欄位都移到 invoices（等使用者挑），也算辨識出內容。
    def recognized?(result)
      result[:items].any? || result[:invoices].present? || result[:fields].keys.intersect?(VISIBLE_FIELDS)
    end

    def render_error(status, code, message, quota: nil)
      render json: { code: code, message: message, quota: quota }.compact, status: status
    end
  end
end
