# 圖檔（憑證附件）的共用處理。規格：docs/資料模型.md §2.4；API：docs/dev/attachments-api.md。
#
# - 圖檔 = ActiveStorage::Blob（實體檔案 + 檔名、類型、大小），blobs 表另記 company_id、uploaded_by_id。
# - 暫存檔 = 還沒掛到任何紀錄的 blob；只有上傳者能掛上、刪除。
# - 掛上紀錄 = 建一筆 ActiveStorage::Attachment（name 為 "attachments"）。同一個 blob 可被多筆紀錄共用，
#   實體檔案在沒有任何紀錄使用時才刪（Blob#purge 遇到還有 attachment 會自動略過）。
module AttachmentFiles
  NAME           = "attachments".freeze
  MAX_COUNT      = 5
  MAX_FILE_BYTES = 5 * 1024 * 1024
  ALLOWED_MIMES  = %w[image/jpeg image/png application/pdf].freeze
  STALE_AFTER    = 24.hours

  # 給 controller 統一回錯；status 預設 422。
  class Error < StandardError
    attr_reader :code, :index, :status

    def initialize(code, message, index: nil, status: :unprocessable_content)
      super(message)
      @code   = code
      @index  = index
      @status = status
    end

    def as_json(*) = { error: code, message: message, index: index }.compact
  end

  module_function

  # ---- 上傳 ----

  # files：ActionDispatch::Http::UploadedFile 陣列。全部通過才建立，回 blob 陣列（順序同 files）。
  def upload!(files, user)
    raise Error.new("NO_FILE", "請選擇要上傳的圖檔") if files.empty?
    raise Error.new("TOO_MANY_FILES", "一次最多上傳 #{MAX_COUNT} 個檔案") if files.size > MAX_COUNT

    mimes = files.each_with_index.map do |file, i|
      mime = detect_mime(file.tempfile)
      unless ALLOWED_MIMES.include?(mime)
        raise Error.new("INVALID_FILE_TYPE", "第 #{i + 1} 個檔案格式不支援，只接受 JPG、PNG、PDF", index: i)
      end
      if file.size > MAX_FILE_BYTES
        raise Error.new("FILE_TOO_LARGE", "第 #{i + 1} 個檔案超過 #{MAX_FILE_BYTES / 1024 / 1024}MB", index: i)
      end
      mime
    end

    files.zip(mimes).map do |file, mime|
      file.tempfile.rewind
      create_blob!(io: file.tempfile, filename: file.original_filename.to_s, content_type: mime, user: user)
    end
  end

  # 建一個暫存檔。content_type 由呼叫端判斷好（看檔案內容），不再讓 ActiveStorage 重判；
  # 標記已分析，掛上時才不會排背景工作去讀檔。
  def create_blob!(io:, filename:, content_type:, user:)
    blob = ActiveStorage::Blob.build_after_unfurling(
      io: io, filename: filename.presence || "file", content_type: content_type,
      metadata: { "identified" => true, "analyzed" => true }, identify: false
    )
    blob.company_id     = user.company_id
    blob.uploaded_by_id = user.id
    blob.upload_without_unfurling(io)
    blob.save!
    blob
  end

  # 只看檔案內容判斷格式，不採信副檔名與瀏覽器送來的 Content-Type。
  def detect_mime(io)
    io.rewind
    Marcel::MimeType.for(io)
  ensure
    io.rewind
  end

  # ---- 暫存檔 ----

  # 只刪自己上傳、同公司、尚未掛上的；其餘略過。
  def discard_uploads!(user, ids)
    ids = clean_ids(ids)
    return if ids.empty?
    unattached(ActiveStorage::Blob.where(id: ids, company_id: user.company_id, uploaded_by_id: user.id)).each(&:purge)
  end

  def unattached(scope)
    scope.where.missing(:attachments)
  end

  # 每日排程：建立超過 24 小時仍未掛上紀錄的暫存檔。
  def purge_stale!
    unattached(ActiveStorage::Blob.where(created_at: ...STALE_AFTER.ago)).find_each(&:purge)
  end

  # ---- 掛上 / 拿掉 ----

  # 要掛上的 id → blob（順序同 ids）。只能掛自己上傳、同公司的檔案；已掛在別的紀錄上也可以（共用）。
  def claim!(user, ids)
    ids = clean_ids(ids)
    return [] if ids.empty?

    blobs = ActiveStorage::Blob.where(id: ids, company_id: user.company_id, uploaded_by_id: user.id).index_by { |b| b.id.to_s }
    raise Error.new("ATTACHMENT_NOT_FOUND", "找不到上傳的圖檔，可能已逾時清除，請重新上傳") unless ids.all? { |id| blobs.key?(id) }

    ids.map { |id| blobs[id] }
  end

  # 依掛上先後排序的 attachment（含 blob）。
  # 已用 with_attached_attachments 載入時不再查詢。
  def attachments_of(record)
    ActiveRecord::Associations::Preloader.new(records: [ record ], associations: { attachments_attachments: :blob }).call
    record.attachments_attachments.sort_by { |a| [ a.created_at, a.id ] }
  end

  def blobs_of(record)
    attachments_of(record).map(&:blob)
  end

  # 編輯時新掛上的檔案接在最後；已掛上的略過。超過上限擋下。須在 record 已存檔後、交易內呼叫。
  # 回傳是否有新掛上。
  def append!(record, blobs)
    existing = blobs_of(record).map(&:id)
    added = blobs.reject { |b| existing.include?(b.id) }
    return false if added.empty?
    raise Error.new("TOO_MANY_ATTACHMENTS", "每筆最多 #{MAX_COUNT} 張圖檔") if existing.size + added.size > MAX_COUNT

    added.each { |blob| ActiveStorage::Attachment.create!(record: record, name: NAME, blob: blob) }
    record.attachments_attachments.reset
    true
  rescue ActiveRecord::InvalidForeignKey
    # 檢查完到掛上之間，暫存檔剛好被每日排程清掉
    raise Error.new("ATTACHMENT_NOT_FOUND", "找不到上傳的圖檔，可能已逾時清除，請重新上傳")
  end

  # 存檔前先檢查張數，錯了就不必進交易。
  def check_count!(record, blobs)
    existing = record.new_record? ? [] : record.attachments_attachments.pluck(:blob_id)
    return if (existing | blobs.map(&:id)).size <= MAX_COUNT
    raise Error.new("TOO_MANY_ATTACHMENTS", "每筆最多 #{MAX_COUNT} 張圖檔")
  end

  # 從紀錄拿掉一張；回傳被拿掉的 blob（呼叫端在交易結束後 purge_unused）。找不到回 nil。
  def detach!(record, blob_id)
    attachment = record.attachments_attachments.find_by(blob_id: blob_id)
    return nil if attachment.nil?
    attachment.delete
    record.attachments_attachments.reset
    attachment.blob
  end

  # 沒有任何紀錄使用的實體檔案刪除；還有紀錄使用的保留（Blob#purge 遇到 attachment 會略過）。
  # 須在交易結束後呼叫，檔案刪了就回不來。
  def purge_unused(blobs)
    Array(blobs).compact.each(&:purge)
  end

  # ---- 輸出 ----

  def as_json(record, user)
    attachments_of(record).map { |a| blob_json(a.blob, user) }
  end

  def blob_json(blob, user)
    {
      id:        blob.id.to_s,
      filename:  blob.filename.to_s,
      mime_type: blob.content_type,
      byte_size: blob.byte_size,
      url:       url_for(blob, user)
    }
  end

  # 稽核用：更新時記檔名陣列。
  def filenames(blobs)
    blobs.map { |b| b.filename.to_s }
  end

  # 稽核用：建立 / 永久刪除的快照只記檔名、類型、大小。沒有圖檔回 nil（快照不加這個 key）。
  def audit_details(record)
    blobs = blobs_of(record)
    return nil if blobs.empty?
    blobs.map { |b| { filename: b.filename.to_s, mime_type: b.content_type, byte_size: b.byte_size } }
  end

  # ---- 讀取 ----

  # 短效簽章網址：token 內含檔案 id、使用者 id，到下一個整點再加一小時失效。
  # 同一小時內產生的網址相同，瀏覽器可以快取。
  def url_for(blob, user)
    "/api/files/#{verifier.generate([ blob.id.to_s, user.id.to_s ], expires_at: url_expires_at)}"
  end

  def url_expires_at
    Time.current.beginning_of_hour + 2.hours
  end

  # token → [blob, user]；無效、過期、找不到、沒有權限都回 nil。
  def resolve_token(token)
    blob_id, user_id = verifier.verified(token.to_s)
    return nil if blob_id.nil?

    user = User.find_by(id: user_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    return nil if user.nil? || blob.nil? || !user.status_active? || !readable?(blob, user)

    [ blob, user ]
  end

  # 管理員可讀公司內所有圖檔；員工只能讀自己上傳的與自己代墊款的圖檔。
  def readable?(blob, user)
    return false unless blob.company_id == user.company_id
    return true if user.role_admin? || blob.uploaded_by_id == user.id

    ActiveStorage::Attachment.where(blob_id: blob.id, record_type: "Reimbursement",
                                    record_id: user.reimbursements.select(:id)).exists?
  end

  # 讀得到的 blob（順序同 ids）；有任何一個讀不到回 nil。
  def readable_blobs(user, ids)
    ids = clean_ids(ids)
    blobs = ActiveStorage::Blob.where(id: ids, company_id: user.company_id).index_by { |b| b.id.to_s }
    return nil unless ids.all? { |id| blobs.key?(id) && readable?(blobs[id], user) }
    ids.map { |id| blobs[id] }
  end

  def verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("attachment_files/url", 32),
      digest: "SHA256", serializer: JSON, url_safe: true
    )
  end

  # ---- 儲存空間 ----

  # 公司所有紀錄（含垃圾桶與代墊款）使用的圖檔大小加總；共用檔只算一次、暫存檔與資料匯出產生的檔案不算。
  def storage_bytes(company)
    ActiveStorage::Blob.where(company_id: company.id)
      .where(id: ActiveStorage::Attachment.where.not(record_type: "DataExport").select(:blob_id)).sum(:byte_size)
  end

  def clean_ids(ids)
    Array(ids).map(&:to_s).map(&:strip).compact_blank.uniq
  end
end
