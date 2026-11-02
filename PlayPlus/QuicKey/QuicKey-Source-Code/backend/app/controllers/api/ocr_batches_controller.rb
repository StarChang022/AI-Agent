module Api
  # 批次匯入憑證（docs/OCR辨識規格.md、docs/資料模型.md §5.5、docs/dev/ocr-batch-api.md）。
  # 先找出每張憑證的位置，使用者確認後才逐張裁切辨識並扣次（扣次 = 辨識出內容的張數）；
  # 僅超級管理員可用，開放支出與收入。
  # - POST   /api/ocr/batch                 上傳檔案，找出每頁每張憑證的框，暫存 30 分鐘，只回每頁張數（不辨識內容、不扣次）
  # - POST   /api/ocr/batch/:token/confirm  選要帶出的頁，逐張裁切辨識、扣次，回每張憑證的內容與所在頁的檔案
  # - DELETE /api/ocr/batch/:token          取消，刪暫存（不扣次）
  # 上傳與確認都會辨識，同一家公司同時只能有一個在進行。
  #
  # 錯誤 payload 同 /api/ocr/recognize：{ code, message, quota?, required? }。
  class OcrBatchesController < ApplicationController
    include OcrUploads

    ROLES          = %w[expense income].freeze
    MAX_FILE_BYTES = 20 * 1024 * 1024
    MAX_PAGES      = 5
    MAX_RECEIPTS   = 50
    TTL            = 30.minutes
    TOKEN          = /\A[A-Za-z0-9_-]{32}\z/
    # 同公司同時只能一批在辨識（上傳、確認共用）；鎖比辨識期限長一點，請求異常中斷時也會自動解除
    BATCH_LOCK_TTL = 120.seconds
    # 轉成 JPEG 的圖片：HEIC（Gemini 不收）、WEBP（憑證附件不收）
    TO_JPEG = %w[image/heic image/webp].freeze
    # 確認後沒扣次的憑證的提醒（接在頁碼或「第幾張」後面）
    RECEIPT_WARNINGS = {
      empty:     "未辨識出內容，未扣次",
      invalid:   "無法辨識，未扣次",
      timed_out: "辨識逾時，未扣次，可重新上傳該頁"
    }.freeze

    before_action :require_admin

    rescue_from Ocr::GeminiClient::Unavailable do |e|
      Rails.logger.warn("[ocr] batch unavailable: #{e.message}")
      render_error(:service_unavailable, "ocr_unavailable", "OCR 服務暫時無法使用，請改手動輸入")
    end
    rescue_from Ocr::Quota::Exhausted do
      render_error(:too_many_requests, "quota_exhausted", "本月 OCR 辨識次數已用完", quota: quota.snapshot)
    end
    rescue_from Ocr::Quota::Insufficient do |e|
      render_error(:too_many_requests, "quota_insufficient", "剩餘 OCR 辨識次數不足（本次需要 #{e.required} 次）",
                   quota: quota.snapshot, required: e.required)
    end

    # POST /api/ocr/batch   multipart: files[], role
    #
    # 檢查順序同 /recognize：role → 檔案數 → 格式 → 大小 → GCP 設定 → 配額（剩 0 次就擋）→ 同公司有批次在辨識
    # → 總頁數 → 找位置。
    def create
      role = params[:role].to_s
      return render_error(:bad_request, "invalid_role", "role 必須是 expense 或 income") unless ROLES.include?(role)

      files = uploaded_files
      return render_error(:bad_request, "invalid_file_type", "請至少上傳 1 個檔案") if files.empty?
      if files.size > ReceiptAttachmentValidation::MAX_COUNT
        return render_error(:bad_request, "too_many_files",
                            "最多 #{ReceiptAttachmentValidation::MAX_COUNT} 個檔案（目前 #{files.size} 個）")
      end

      mimes = files.map { |f| detect_mime(f) }
      if (index = mimes.index { |m| !ALLOWED_MIMES.include?(m) })
        return render_error(:bad_request, "invalid_file_type",
                            "第 #{index + 1} 個檔案格式不支援（只接受 JPG／PNG／WEBP／HEIC／PDF）")
      end
      if (index = files.index { |f| f.size > MAX_FILE_BYTES })
        return render_error(:content_too_large, "file_too_large",
                            "第 #{index + 1} 個檔案超過 #{MAX_FILE_BYTES / 1024 / 1024}MB 上限")
      end

      client = Ocr::GeminiClient.from_env
      quota.ensure_any_remaining!

      with_batch_lock { locate_batch(files, mimes, role, client) }
    end

    # POST /api/ocr/batch/:token/confirm   JSON: { page_ids: [...] }
    #
    # 先確認次數夠所選頁的框數（不夠時暫存保留，使用者可改選頁數），再逐張辨識，辨識完只扣辨識出內容的張數。
    # Google 無法使用時不扣次、暫存保留，可以再確認一次。
    def confirm
      key = cache_key(params[:token])
      return render_batch_expired unless key

      client = Ocr::GeminiClient.from_env
      with_batch_lock { confirm_batch(key, Array(params[:page_ids]).map(&:to_s).uniq, client) }
    end

    # DELETE /api/ocr/batch/:token   找不到也回 204
    def destroy
      key = cache_key(params[:token])
      Rails.cache.delete(key) if key
      head :no_content
    end

    private

    def locate_batch(files, mimes, role, client)
      warnings = []
      documents = prepare_documents(files, mimes, warnings)
      total_pages = documents.sum { |d| d[:pages] }
      if total_pages > MAX_PAGES
        return render_error(:bad_request, "too_many_pages", "最多 #{MAX_PAGES} 頁（目前 #{total_pages} 頁）")
      end

      pages = split_pages(documents, warnings)
      results = Ocr::BatchRecognizer.locate(pages, client: client)
      entry_pages = build_entry_pages(results, warnings)
      receipt_count = entry_pages.sum { |p| p[:boxes].size }
      if receipt_count.zero?
        return render_error(:unprocessable_content, "ocr_no_result", "無法辨識憑證內容，請改手動輸入",
                            quota: quota.snapshot)
      end

      token = SecureRandom.urlsafe_base64(24)
      expires_at = TTL.from_now
      entry = { role: role, pages: entry_pages, warnings: warnings }
      unless Rails.cache.write(cache_key(token), entry, expires_in: TTL)
        raise Ocr::GeminiClient::Unavailable, "batch cache write failed"
      end

      render json: {
        token:         token,
        expires_at:    expires_at.iso8601,
        receipt_count: receipt_count,
        pages: entry_pages.map do |p|
          { page_id: p[:id], file_index: p[:file_index], filename: p[:filename],
            page_number: p[:number], receipt_count: p[:boxes].size }
        end,
        warnings:      warnings + entry_pages.flat_map { |p| p[:warnings] },
        quota:         quota.snapshot
      }
    end

    # 暫存在鎖內讀（同一批同時確認兩次時，後到的拿不到鎖或讀不到暫存）。辨識完在公司資料列鎖內刪暫存、扣次；
    # 刪暫存的結果決定誰搶到（快取鎖極少數會兩個都通過，這裡保證只扣一次）。
    # 所選的憑證全部辨識不出內容時照樣回 200（receipts 為空、不扣次），暫存照常刪掉。
    def confirm_batch(key, page_ids, client)
      entry = Rails.cache.read(key)
      return render_batch_expired unless entry

      selected = entry[:pages].select { |p| page_ids.include?(p[:id]) }
      if page_ids.empty? || selected.size != page_ids.size
        return render_error(:bad_request, "invalid_page_ids", "選擇的頁面有誤，請重新選擇")
      end
      required = selected.sum { |p| p[:boxes].size }
      return render_error(:bad_request, "invalid_page_ids", "選擇的頁面沒有憑證，請重新選擇") if required.zero?
      quota.ensure_available!(required)

      selections = selected.map { |p| [ batch_page(p), p[:boxes] ] }
      results = Ocr::BatchRecognizer.recognize(selections, client: client, role: entry[:role])
      count = results.sum { |receipts| receipts.count { |r| r.status == :recognized } }

      used = current_user.company.with_lock do
        raise ActiveRecord::Rollback unless Rails.cache.delete(key)
        quota.consume!(count)
      end
      return render_batch_expired if used.nil?

      render_confirmed(selected, results, used)
    end

    def render_confirmed(selected, results, used)
      receipts = []
      pages = []
      warnings = []
      selected.zip(results).each do |p, page_results|
        page = batch_page(p)
        warnings.concat(p[:warnings])
        warnings.concat(receipt_warnings(page, page_results))

        recognized = page_results.select { |r| r.status == :recognized }
        next if recognized.empty?

        recognized.each do |r|
          receipts << { page_id: page.id, page_number: page.number, filename: page.filename, result: r.result }
        end
        attachment = attachment_json(page)
        pages << { page_id: page.id, attachment: attachment }
        if attachment.nil?
          warnings << "#{page_label(page)}的檔案超過 #{ReceiptAttachmentValidation::MAX_FILE_BYTES / 1024 / 1024}MB，" \
                      "未附上憑證檔，請自行補上"
        end
      end

      render json: { receipts: receipts, pages: pages, warnings: warnings, quota: quota.snapshot(used: used) }
    end

    # 沒扣次的憑證：整頁都是同一種原因時只提醒一次；否則每張各自提醒（第幾張照找到的順序，由上到下、由左到右）。
    def receipt_warnings(page, page_results)
      statuses = page_results.map(&:status)
      if statuses.size > 1 && statuses.uniq.size == 1 && RECEIPT_WARNINGS.key?(statuses.first)
        return [ "#{page_label(page)}#{RECEIPT_WARNINGS[statuses.first]}" ]
      end

      statuses.each_with_index.filter_map do |status, n|
        next unless RECEIPT_WARNINGS.key?(status)
        label = statuses.size > 1 ? "#{page_label(page)}第 #{n + 1} 張" : page_label(page)
        "#{label}#{RECEIPT_WARNINGS[status]}"
      end
    end

    # 用快取當鎖：寫入成功、且讀回來是自己寫的值才算拿到（solid_cache 對不存在的 key 不是原子寫入）。
    # 請求結束一定釋放（只刪自己的鎖），辨識出錯也一樣。
    def with_batch_lock
      key = "ocr_batch_lock/#{current_user.company_id}"
      owner = SecureRandom.hex(16)
      acquired = Rails.cache.write(key, owner, unless_exist: true, expires_in: BATCH_LOCK_TTL) &&
                 Rails.cache.read(key) == owner
      return render_error(:conflict, "batch_in_progress", "上一批憑證還在辨識中，請稍候再試") unless acquired

      yield
    ensure
      Rails.cache.delete(key) if acquired && Rails.cache.read(key) == owner
    end

    def render_batch_expired
      render_error(:not_found, "batch_expired", "辨識結果已過期，請重新上傳")
    end

    def require_admin
      return if current_user&.role_admin?
      render_error(:forbidden, "forbidden", "只有管理員可以使用批次匯入")
    end

    def quota
      @quota ||= Ocr::Quota.new(current_user.company)
    end

    # key 綁公司與使用者：別家公司或別人的 token 一律查不到（回 404）。
    def cache_key(token)
      "ocr_batch/#{current_user.company_id}/#{current_user.id}/#{token}" if token.to_s.match?(TOKEN)
    end

    # 轉檔並數頁；轉檔失敗、讀不出頁數的檔案略過（不送 Google）。圖片 1 頁。
    def prepare_documents(files, mimes, warnings)
      files.each_with_index.filter_map do |file, i|
        bytes, mime = document_payload(file, mimes[i], to_jpeg: TO_JPEG)
        pages = mime == "application/pdf" ? Ocr::PdfPages.count(bytes) : 1
        { index: i, filename: file.original_filename.to_s, bytes: bytes, mime: mime, pages: pages }
      rescue Ocr::GeminiClient::InvalidDocument, Ocr::PdfPages::Unreadable, Vips::Error => e
        Rails.logger.warn("[ocr] batch file #{i} rejected: #{e.message}")
        warnings << "第 #{i + 1} 個檔案無法辨識，已略過"
        nil
      end
    end

    # PDF 拆成單頁，每頁各自找位置、各自當附件；圖片整張就是一頁。
    def split_pages(documents, warnings)
      documents.flat_map do |doc|
        contents = doc[:mime] == "application/pdf" ? Ocr::PdfPages.split(doc[:bytes]) : [ doc[:bytes] ]
        contents.each_with_index.map do |bytes, n|
          Ocr::BatchRecognizer::Page.new(id: "#{doc[:index]}-#{n + 1}", file_index: doc[:index],
                                         filename: doc[:filename], number: n + 1, bytes: bytes, mime: doc[:mime])
        end
      rescue Ocr::PdfPages::Unreadable => e
        Rails.logger.warn("[ocr] batch file #{doc[:index]} split failed: #{e.message}")
        warnings << "第 #{doc[:index] + 1} 個檔案無法辨識，已略過"
        []
      end
    end

    # 暫存的每頁資料：頁的原始內容（確認時裁切、當附件）、找到的框（每頁最多 10 張、整批最多 50 張）與這頁的提醒。
    def build_entry_pages(results, warnings)
      remaining = MAX_RECEIPTS
      dropped = false
      entry_pages = results.map do |r|
        page = r.page
        page_warnings = []
        label = page_label(page)
        page_warnings << "#{label}無法辨識，已略過" if r.invalid
        page_warnings << "#{label}辨識逾時，未扣次，可重新上傳該頁" if r.timed_out
        page_warnings << "#{label}超過 #{Ocr::BatchRecognizer::MAX_PER_PAGE} 張憑證，只取前 #{Ocr::BatchRecognizer::MAX_PER_PAGE} 張" if r.truncated

        boxes = r.boxes.first(remaining)
        dropped ||= boxes.size < r.boxes.size
        remaining -= boxes.size

        { id: page.id, file_index: page.file_index, filename: page.filename, number: page.number,
          bytes: page.bytes, mime: page.mime, boxes: boxes, warnings: page_warnings }
      end
      warnings << "憑證超過 #{MAX_RECEIPTS} 張，只取前 #{MAX_RECEIPTS} 張" if dropped
      entry_pages
    end

    def batch_page(entry_page)
      Ocr::BatchRecognizer::Page.new(**entry_page.slice(:id, :file_index, :filename, :number, :bytes, :mime))
    end

    def page_label(page)
      page.mime == "application/pdf" ? "第 #{page.file_index + 1} 個檔案第 #{page.number} 頁" : "第 #{page.file_index + 1} 個檔案"
    end

    # 所在頁轉成新增支出／收入的憑證格式（data URL）；超過單檔上限回 nil，由使用者自己補。
    def attachment_json(page)
      return nil if page.bytes.bytesize > ReceiptAttachmentValidation::MAX_FILE_BYTES
      {
        data_url:  "data:#{page.mime};base64,#{Base64.strict_encode64(page.bytes)}",
        filename:  attachment_filename(page),
        mime_type: page.mime
      }
    end

    # PDF 的單頁加上頁碼（收據.pdf → 收據_p2.pdf）；轉成 JPEG 的圖片改副檔名。
    def attachment_filename(page)
      base = File.basename(page.filename, ".*").presence || "receipt"
      case page.mime
      when "application/pdf" then "#{base}_p#{page.number}.pdf"
      when "image/jpeg"      then File.extname(page.filename).match?(/\A\.jpe?g\z/i) ? page.filename : "#{base}.jpg"
      else page.filename
      end
    end
  end
end
