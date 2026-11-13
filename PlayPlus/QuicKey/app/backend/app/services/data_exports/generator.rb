require "zip"

module DataExports
  # 背景產生匯出檔（PRD 第 24 條）：依條件重查紀錄，產生一份 CSV，有圖檔時另加一個 ZIP，
  # 存成 DataExport 的 files。紀錄分批讀、CSV 邊讀邊寫到暫存檔、圖檔逐塊寫進 ZIP 再上傳，
  # 整家公司的資料不會一次進記憶體。
  class Generator
    # CSV 檔名開頭，例：支出_2026-11-09.csv。
    FILE_PREFIXES = { "expense" => "支出", "income" => "收入", "reimbursement" => "代墊款" }.freeze
    # ZIP 檔名不能用的字元（Windows 檔名限制＋路徑分隔）。
    UNSAFE_CHARS = %r{[\\/:*?"<>|\x00-\x1F]}
    # 檔名標記為 UTF-8（ZIP 的 EFS 旗標），Windows 檔案總管與 macOS 解壓縮中文才不會亂碼。
    # 只設在這個 entry 上，不改全域的 Zip.unicode_names（會影響 caxlsx 產生的 XLSX）。
    EFS_FLAG = 0b1000_0000_0000

    def initialize(data_export)
      @export = data_export
      @today  = Time.current.to_date.iso8601
    end

    # 回產生的筆數。
    def call
      count = 0
      Dir.mktmpdir("data-export") do |dir|
        zip_entries = [] # [ZIP 內檔名, blob id]

        section = Selection.new(@export).section
        path = File.join(dir, "#{section.type}.csv")
        File.open(path, "wb") do |file|
          Csv.lines(Csv::HEADERS[section.type], section_rows(section, zip_entries) { count += 1 })
             .each { |line| file.write(line) }
        end
        store!(path, "#{section.type}_csv", "#{FILE_PREFIXES[section.type]}_#{@today}.csv", "text/csv")

        if zip_entries.any?
          path = File.join(dir, "attachments.zip")
          write_zip(path, zip_entries)
          store!(path, "attachments_zip", "圖檔_#{@today}.zip", "application/zip")
        end
      end
      count
    end

    private

    # 分批讀出 CSV 列；圖檔排進 zip_entries，CSV 圖檔欄記 ZIP 內檔名。
    def section_rows(section, zip_entries)
      used = Set.new
      Enumerator.new do |y|
        section.each_record(with_attachments: true) do |record|
          yield
          names = AttachmentFiles.attachments_of(record).map do |attachment|
            name = unique_name(entry_name(section.type, record, attachment.blob), used)
            zip_entries << [ name, attachment.blob_id ]
            name
          end
          y << Csv.row(section.type, record, names)
        end
      end
    end

    # 「發生日期_賣方或客戶或申請人_原始檔名」；名稱空白時略過該段。
    def entry_name(type, record, blob)
      date, party =
        case type
        when "expense"       then [ record.date, record.vendor ]
        when "income"        then [ record.date, record.customer ]
        when "reimbursement" then [ record.incurred_at, record.employee&.name ]
        end
      [ date&.iso8601, party, blob.filename.to_s ].map { |part| sanitize(part) }.compact_blank.join("_")
    end

    def sanitize(part)
      part.to_s.gsub(UNSAFE_CHARS, "_").strip
    end

    # 同名時加序號（不分大小寫）：a.jpg、a(2).jpg、a(3).jpg。
    def unique_name(name, used)
      ext  = File.extname(name)
      base = name.delete_suffix(ext)
      candidate = name
      n = 1
      while used.include?(candidate.downcase)
        n += 1
        candidate = "#{base}(#{n})#{ext}"
      end
      used << candidate.downcase
      candidate
    end

    # 圖檔分批查出、逐塊寫進 ZIP。
    def write_zip(path, entries)
      Zip::OutputStream.open(path) do |zip|
        entries.each_slice(Selection::BATCH_SIZE) do |slice|
          blobs = ActiveStorage::Blob.where(id: slice.map(&:last)).index_by(&:id)
          slice.each do |name, blob_id|
            zip.put_next_entry(utf8_entry(path, name))
            blobs.fetch(blob_id).download { |chunk| zip.write(chunk) }
          end
        end
      end
    end

    def utf8_entry(zip_path, name)
      Zip::Entry.new(zip_path, name).tap { |entry| entry.gp_flags |= EFS_FLAG }
    end

    # 存成 DataExport 的檔案。blobs 表的公司、上傳者必填，記發起人；儲存空間不計
    # 掛在 DataExport 上的檔案（AttachmentFiles.storage_bytes）。
    def store!(path, key, filename, content_type)
      File.open(path, "rb") do |io|
        blob = ActiveStorage::Blob.build_after_unfurling(
          io: io, filename: filename, content_type: content_type,
          metadata: { "identified" => true, "analyzed" => true, "key" => key }, identify: false
        )
        blob.company_id     = @export.company_id
        blob.uploaded_by_id = @export.requested_by_id
        blob.upload_without_unfurling(io)
        blob.save!
        @export.files.attach(blob)
      end
    end
  end
end
