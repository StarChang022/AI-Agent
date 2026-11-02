module ReceiptAttachmentValidation
  # 憑證 data URL 的三道驗證：張數、MIME 類型、單檔大小。
  # Reimbursement.receipt_urls（string[]）與 Expense.attachments（jsonb[]）shape 不同，
  # 由各自 model 抽出純 data URL 陣列後呼叫 .apply。
  #
  # 【原型】目前憑證以 base64 data URL 存 DB；接 ActiveStorage 後本模組會改成驗
  # ActiveStorage::Blob。閾值跟前端 ExpenseFormView 常數（MAX_ATTACHMENTS=5、
  # MAX_ATTACHMENT_MB=10、accept="image/*,application/pdf"）保持一致。

  MAX_COUNT      = 5
  ALLOWED_MIMES  = %w[image/jpeg image/png application/pdf].freeze
  MAX_FILE_BYTES = 5 * 1024 * 1024

  module_function

  def apply(record, field, data_urls)
    urls = Array(data_urls).compact

    if urls.length > MAX_COUNT
      record.errors.add(field, "最多 #{MAX_COUNT} 張憑證（目前 #{urls.length} 張）")
    end

    urls.each_with_index do |url, i|
      prefix, payload = url.to_s.split(",", 2)
      m = prefix&.match(/\Adata:([^;]+);base64\z/)

      unless m && payload
        record.errors.add(field, "第 #{i + 1} 張憑證格式錯誤（非 base64 data URL）")
        next
      end

      mime = m[1]
      unless ALLOWED_MIMES.include?(mime)
        record.errors.add(field, "第 #{i + 1} 張憑證不支援 #{mime}（只接受 JPG／PNG／PDF）")
      end

      # base64 解碼後 bytes：payload 每 4 字元 → 3 bytes，末尾 '=' 補位要扣掉
      pad = payload.count("=")
      raw_bytes = (payload.length * 3 / 4) - pad
      next unless raw_bytes > MAX_FILE_BYTES

      mb = (raw_bytes.to_f / 1024 / 1024).round(1)
      record.errors.add(field, "第 #{i + 1} 張憑證 #{mb}MB，超過 #{MAX_FILE_BYTES / 1024 / 1024}MB 上限")
    end
  end
end
