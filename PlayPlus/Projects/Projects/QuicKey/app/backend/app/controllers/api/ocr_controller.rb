module Api
  # 憑證 OCR endpoints。見 docs/OCR辨識規格.md。
  # - POST /api/ocr/recognize  上傳 1–5 張同一張憑證的照片 / PDF，回合併結果 + 衝突清單
  # - GET  /api/ocr/quota      查本公司剩餘次數；管理員與員工都可查（員工代墊款表單要顯示）
  #
  # 錯誤 payload：{ code, message, quota?, required? }（quota 在 429 與 422 附上；422 有扣次，前端用它更新剩餘次數；
  # required 只在 quota_insufficient 附上，是本次需要的次數）。
  class OcrController < ApplicationController
    include OcrUploads

    # POST /api/ocr/recognize   JSON 或 multipart: attachment_ids[], role
    # attachment_ids 是已上傳的圖檔（暫存檔或紀錄已存的圖檔），須是目前使用者讀得到的
    # （docs/dev/attachments-api.md 第 7 節）。
    #
    # 檢查順序：role → 張數 → 圖檔存在 → 格式 → 大小 → GCP 設定 → 算頁數 → 配額（總頁數）→ 逐檔辨識。
    # 只有 Gemini 成功回傳的檔案才扣次（按實際頁數）；任一檔遇到 503 類錯誤就整個回 503、不扣次。
    def recognize
      role = params[:role].to_s
      unless Ocr::ReceiptExtractor::ROLES.include?(role)
        return render_error(:bad_request, "invalid_role", "role 必須是 expense / reimbursement / income")
      end

      ids = AttachmentFiles.clean_ids(params[:attachment_ids])
      if ids.empty?
        return render_error(:bad_request, "invalid_file_type", "請至少上傳 1 個檔案")
      end
      if ids.size > AttachmentFiles::MAX_COUNT
        return render_error(:bad_request, "too_many_files",
                            "最多 #{AttachmentFiles::MAX_COUNT} 個檔案（目前 #{ids.size} 個）")
      end

      blobs = AttachmentFiles.readable_blobs(current_user, ids)
      if blobs.nil?
        return render_error(:bad_request, "attachment_not_found", "找不到要辨識的圖檔，請重新上傳")
      end
      files = blob_files(blobs)

      mimes = files.map { |f| detect_mime(f) }
      if (index = mimes.index { |m| !ALLOWED_MIMES.include?(m) })
        return render_error(:bad_request, "invalid_file_type",
                            "第 #{index + 1} 個檔案格式不支援（只接受 JPG／PNG／WEBP／HEIC／PDF）")
      end
      if (index = files.index { |f| f.size > AttachmentFiles::MAX_FILE_BYTES })
        return render_error(:payload_too_large, "file_too_large",
                            "第 #{index + 1} 個檔案超過 #{AttachmentFiles::MAX_FILE_BYTES / 1024 / 1024}MB 上限")
      end

      client = Ocr::GeminiClient.from_env
      quota  = Ocr::Quota.new(current_user.company)
      quota.ensure_any_remaining!

      # 先算好每個檔案的內容與頁數，再用總頁數擋配額：不夠就整個不辨識、不扣次。
      # 轉檔失敗、頁數過多 / 讀不出來的檔案不送 Google，不算進需要的次數。
      results  = []
      warnings = []
      prepared = files.each_with_index.filter_map do |file, i|
        bytes, mime = document_payload(file, mimes[i])
        { index: i, bytes: bytes, mime: mime, pages: page_count(bytes, mime) }
      rescue Ocr::GeminiClient::InvalidDocument, Ocr::PdfPages::Unreadable, Vips::Error => e
        Rails.logger.warn("[ocr] file #{i} rejected: #{e.message}")
        warnings << "第 #{i + 1} 個檔案無法辨識，已略過"
        nil
      end
      required = prepared.sum { |f| f[:pages] }
      quota.ensure_available!(required)

      pages = 0

      prepared.each do |file|
        i = file[:index]
        invoices = scan_invoices(file[:bytes], file[:mime], i)
        response = client.recognize(file[:bytes], file[:mime])
        pages += file[:pages]

        extracted = extract_fields(response.data, role, i)
        result = Ocr::InvoiceQr.apply(extracted, invoices, role: role, source_index: i,
                                      names: party_names(response.data, role))
        if result && Ocr::ResultMerger.recognized?(result)
          results << result
        else
          warnings << "第 #{i + 1} 個檔案未辨識出內容"
        end
      rescue Ocr::GeminiClient::InvalidDocument => e
        Rails.logger.warn("[ocr] file #{i} rejected: #{e.message}")
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
    rescue Ocr::GeminiClient::Unavailable => e
      Rails.logger.warn("[ocr] unavailable: #{e.message}")
      render_error(:service_unavailable, "ocr_unavailable", "OCR 服務暫時無法使用，請改手動輸入")
    rescue Ocr::Quota::Exhausted
      render_error(:too_many_requests, "quota_exhausted", "本月 OCR 辨識次數已用完",
                   quota: quota.snapshot)
    rescue Ocr::Quota::Insufficient => e
      render_error(:too_many_requests, "quota_insufficient", "剩餘 OCR 辨識次數不足（本次需要 #{e.required} 次）",
                   quota: quota.snapshot, required: e.required)
    ensure
      files&.each { |f| f.tempfile.close! }
    end

    # GET /api/ocr/quota
    def quota
      quota = Ocr::Quota.new(current_user.company)
      quota.refresh!
      render json: quota
    end

    private

    # 圖檔下載成暫存檔，沿用原本處理上傳檔案的流程（看內容判斷格式、HEIC 轉檔、數頁）。
    def blob_files(blobs)
      blobs.map do |blob|
        tempfile = Tempfile.new([ "ocr", blob.filename.extension_with_delimiter ], binmode: true)
        blob.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(tempfile: tempfile, filename: blob.filename.to_s, type: blob.content_type)
      end
    end

    # 圖片 1 頁；PDF 用 pdfinfo 數頁，超過上限當作檔案無法辨識（不送 Google、不扣次）。
    def page_count(bytes, mime)
      return 1 unless mime == "application/pdf"
      pages = Ocr::PdfPages.count(bytes)
      raise Ocr::GeminiClient::InvalidDocument, "too many pages" if pages > Ocr::PdfPages::MAX_PAGES
      pages
    end

    # 抽欄位出任何錯都當作這個檔案沒有結果；Google 已計費，頁數照算進扣次。
    # log 只記錯誤類別與訊息，不記內容與統編。
    def extract_fields(data, role, index)
      Ocr::ReceiptExtractor.call(data, role: role, source_index: index)
    rescue StandardError => e
      Rails.logger.error("[ocr] file #{index} extract failed: #{e.class}: #{e.message}")
      nil
    end

    def party_names(data, role)
      Ocr::ReceiptExtractor.new(data, role: role, source_index: nil).party_names
    rescue StandardError
      {}
    end

    # 電子發票 QR（docs/OCR辨識規格.md §3.2）：解不出來或出任何錯都當作沒有 QR，不影響辨識。
    # log 只記錯誤類別與訊息，不記 QR 內容。
    def scan_invoices(bytes, mime, index)
      Ocr::InvoiceQr.call(Ocr::QrScanner.call(bytes, mime))
    rescue StandardError => e
      Rails.logger.info("[ocr] file #{index} qr parse failed: #{e.class}: #{e.message}")
      []
    end
  end
end
