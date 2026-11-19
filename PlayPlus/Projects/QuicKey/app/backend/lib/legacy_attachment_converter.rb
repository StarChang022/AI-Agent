# 既有 base64 圖檔一次性轉成實體檔案（docs/資料模型.md §2.4「既有資料轉檔」）。
# 由 db/migrate/20261103000003（轉檔）與 20261103000004（確認後移除舊欄位）使用。系統搬移，不寫稽核。
#
# - 掛回原紀錄、檔名不變；上傳者記為紀錄的建立者（代墊款為申請人）。
# - 代墊款核准產生的支出若跟代墊款是同一張圖（內容相同），改成共用同一個檔案。
# - 可重跑：紀錄已有圖檔就略過。任何一張解不開就整個中止，不丟資料。
# - 直接寫 attachments 表，不經 ActiveStorage 的 callback，紀錄的 updated_at 不會被改動。
class LegacyAttachmentConverter
  class Invalid < StandardError; end

  NAME = AttachmentFiles::NAME

  # items：[{ data_url:, filename: }]（順序即顯示順序）。share_with：[record_type, record_id]，
  # 內容相同時共用該紀錄的檔案。回傳 :converted / :skipped。
  def convert!(record_type:, record_id:, company_id:, uploaded_by_id:, items:, share_with: nil)
    return :skipped if items.empty? || converted?(record_type, record_id)

    # 先全部解開再寫檔：中途有一張解不開時，硬碟上不會留下沒有紀錄的檔案
    decoded = items.each_with_index.map { |item, i| decode!(item[:data_url], record_type, record_id, i) }
    shareable = share_with ? blobs_of(*share_with) : []
    base_time = Time.current
    ActiveRecord::Base.transaction do
      items.each_with_index do |item, i|
        bytes = decoded[i]
        checksum = OpenSSL::Digest::MD5.base64digest(bytes)
        blob = shareable.find { |b| b.checksum == checksum && b.byte_size == bytes.bytesize }
        blob ||= create_blob!(bytes, item[:filename].presence || "receipt-#{i + 1}", item[:data_url], company_id, uploaded_by_id)
        # created_at 依原順序遞增，讀出時順序不變
        ActiveStorage::Attachment.insert!({ name: NAME, record_type: record_type, record_id: record_id,
                                            blob_id: blob.id, created_at: base_time + (i * 0.001) })
      end
    end
    :converted
  end

  # 確認舊圖都找得到：每張舊圖在紀錄上都有內容相同的檔案，且實體檔案讀得到、內容正確。不符就 raise。
  # 不要求張數相同：轉檔後到確認前若有人加了圖，仍可重試。
  def verify!(record_type:, record_id:, items:)
    blobs = blobs_of(record_type, record_id)
    items.each_with_index do |item, i|
      bytes = decode!(item[:data_url], record_type, record_id, i)
      checksum = OpenSSL::Digest::MD5.base64digest(bytes)
      blob = blobs.find { |b| b.checksum == checksum && b.byte_size == bytes.bytesize }
      raise Invalid, "#{record_type} #{record_id} 第 #{i + 1} 張：找不到轉好的檔案" if blob.nil?
      next if blob.download == bytes

      raise Invalid, "#{record_type} #{record_id} 第 #{i + 1} 張：實體檔案內容與原本不同"
    end
  rescue ActiveStorage::FileNotFoundError
    raise Invalid, "#{record_type} #{record_id}：實體檔案不存在"
  end

  private

  def converted?(record_type, record_id)
    ActiveStorage::Attachment.exists?(record_type: record_type, record_id: record_id, name: NAME)
  end

  def blobs_of(record_type, record_id)
    ActiveStorage::Attachment.where(record_type: record_type, record_id: record_id, name: NAME)
      .includes(:blob).order(:created_at, :id).map(&:blob)
  end

  def decode!(data_url, record_type, record_id, index)
    prefix, payload = data_url.to_s.split(",", 2)
    raise Invalid, "#{record_type} #{record_id} 第 #{index + 1} 張不是 base64 data URL" unless prefix&.match?(/\Adata:[^;]*;base64\z/) && payload

    Base64.strict_decode64(payload.delete("\n\r"))
  rescue ArgumentError
    raise Invalid, "#{record_type} #{record_id} 第 #{index + 1} 張 base64 解不開"
  end

  # 類型看檔案內容；判斷不出來時用原本記錄的類型。舊資料照原樣保存，不套用新上傳的格式限制。
  def create_blob!(bytes, filename, data_url, company_id, uploaded_by_id)
    declared = data_url.to_s[/\Adata:([^;]+);/, 1]
    detected = Marcel::MimeType.for(StringIO.new(bytes))
    mime = detected == "application/octet-stream" && declared.present? ? declared : detected

    io = StringIO.new(bytes)
    blob = ActiveStorage::Blob.build_after_unfurling(
      io: io, filename: filename, content_type: mime,
      metadata: { "identified" => true, "analyzed" => true }, identify: false
    )
    blob.company_id     = company_id
    blob.uploaded_by_id = uploaded_by_id
    blob.upload_without_unfurling(io)
    blob.save!
    blob
  end
end
