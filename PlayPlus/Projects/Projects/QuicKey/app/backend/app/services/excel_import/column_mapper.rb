module ExcelImport
  # 解析第 2 段「欄位對應」：依標題名稱找欄（不依位置），回傳 { 欄位 key => 欄位索引 }。
  # 首版固定比對範本標題；column_mapping（{ 欄位 key => 使用者檔案的標題 }）為之後
  # 支援自訂格式預留，有帶時優先採用。
  class ColumnMapper
    def self.map(headers, schema, column_mapping = nil)
      normalized = headers.map { |h| normalize(h) }
      overrides  = (column_mapping || {}).to_h.transform_keys(&:to_s)

      schema.fields.each_with_object({}) do |field, index|
        wanted = normalize(overrides[field.key.to_s].presence || field.header)
        position = normalized.index(wanted)
        if position
          index[field.key] = position
        elsif field.required
          raise Error.new("MISSING_COLUMN", "找不到「#{field.header}」欄，請使用範本")
        end
      end
    end

    # 標題去頭尾空白（含全形）、忽略 *。
    def self.normalize(header)
      header.to_s.delete("*＊").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    end
  end
end
