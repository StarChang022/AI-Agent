require "roo"
require "zip"

module ExcelImport
  # 解析第 1 段「讀表」：檢查檔案限制，讀第一個工作表的標題列（第 1 列）與資料列。
  # 回傳的 rows 為 [Excel 列號, 儲存格原始值陣列]，整列空白的列略過。
  class SheetReader
    MAX_BYTES          = 5.megabytes
    MAX_ROWS           = 1_000
    # 防壓縮炸彈與大量空白列：解壓後總大小、zip 內檔案數、實體列號上限。
    # 超過 MAX_COLUMNS 的欄直接忽略（範本只有 18 欄）。
    MAX_UNZIPPED_BYTES = 50.megabytes
    MAX_ZIP_ENTRIES    = 500
    MAX_ROW_NUMBER     = 10_000
    MAX_COLUMNS        = 100

    Sheet = Data.define(:headers, :rows)

    def self.read(upload)
      raise Error.new("FILE_REQUIRED", "請選擇要匯入的檔案") unless upload.respond_to?(:path) && upload.respond_to?(:original_filename)
      raise Error.new("INVALID_FILE_TYPE", "只接受 .xlsx 檔") unless File.extname(upload.original_filename.to_s).casecmp?(".xlsx")
      raise Error.new("FILE_TOO_LARGE", "檔案超過 5 MB") if upload.size > MAX_BYTES

      check_zip!(upload.path)
      read_rows(upload.path)
    rescue Error
      raise
    rescue StandardError => e
      # 損毀或非 Excel 存檔的檔案，Roo / rubyzip 可能在開檔或逐列讀取時才出錯
      Rails.logger.warn("[ExcelImport] unreadable file: #{e.class}: #{e.message}")
      raise Error.new("UNREADABLE_FILE", "無法讀取檔案，請確認是 Excel 存檔的 .xlsx")
    end

    # 依 zip 目錄記載的解壓後大小把關；實際解壓超過記載值時 rubyzip 會拋錯（validate_entry_sizes）。
    def self.check_zip!(path)
      Zip::File.open(path) do |zip|
        entries = zip.entries
        if entries.size > MAX_ZIP_ENTRIES || entries.sum(&:size) > MAX_UNZIPPED_BYTES
          raise Error.new("FILE_TOO_LARGE", "檔案內容過大，請刪除多餘的工作表或資料後再匯入")
        end
      end
    end

    def self.read_rows(path)
      headers = nil
      rows    = []
      Roo::Excelx.new(path).each_row_streaming do |cells|
        cells = cells.compact
        next if cells.empty?

        number = cells.first.coordinate.row
        if number > MAX_ROW_NUMBER
          raise Error.new("TOO_MANY_ROWS", "檔案超過 #{MAX_ROW_NUMBER.to_fs(:delimited)} 列（含空白列），請刪除多餘的列後再匯入")
        end

        values = row_values(cells)
        if number == 1
          headers = values
          next
        end
        next if values.all? { |v| ValueParser.blank?(v) }

        rows << [ number, values ]
        raise Error.new("TOO_MANY_ROWS", "資料超過 #{MAX_ROWS.to_fs(:delimited)} 列，請分批匯入") if rows.size > MAX_ROWS
      end

      Sheet.new(headers: headers || [], rows: rows)
    end

    # 依儲存格的欄位置排成陣列（第 1 欄 = 索引 0），超過 MAX_COLUMNS 的欄忽略。
    def self.row_values(cells)
      cells.each_with_object([]) do |cell, values|
        column = cell.coordinate.column
        values[column - 1] = cell.value if column <= MAX_COLUMNS
      end
    end
  end
end
