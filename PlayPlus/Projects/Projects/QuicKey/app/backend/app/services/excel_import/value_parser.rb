module ExcelImport
  # 解析第 3 段「值轉換」：把儲存格原始值（Roo 回的 String / Integer / Float / Date）
  # 轉成系統值。看不懂一律回 nil，由 Parser 決定是不匯入還是補預設值。
  module ValueParser
    EXCEL_EPOCH  = Date.new(1899, 12, 30)
    MIN_YEAR     = 2000
    TAX_ID_WEIGHTS = [ 1, 2, 1, 2, 1, 2, 4, 1 ].freeze
    # 金額欄上限（資料表為 numeric(12,2)），品項小計與加總同此上限。
    MAX_MONEY      = BigDecimal("9999999999.99")

    module_function

    def blank?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    # 儲存格轉文字；整數形式的數字去掉 .0（例：統編被 Excel 存成數字）。
    def text(value)
      return nil if blank?(value)
      case value
      when Float      then value == value.floor ? value.to_i.to_s : value.to_s
      when Date, Time then value.to_date.iso8601
      else value.to_s.strip
      end
    end

    # 接受 Excel 日期、日期序號、2026/10/29、2026-10-29、民國 115/10/29；
    # 年份限 2000 年到今年 + 1 年。
    def date(value, today: Date.current)
      parsed =
        case value
        when Date, Time then value.to_date
        when Numeric    then EXCEL_EPOCH + value.to_i
        when String     then date_from_text(value.strip)
        end
      parsed if parsed && parsed.year.between?(MIN_YEAR, today.year + 1)
    end

    def date_from_text(text)
      m = text.match(%r{\A(\d{2,4})[/\-.](\d{1,2})[/\-.](\d{1,2})\z})
      return nil if m.nil?
      year = m[1].to_i
      year += 1911 if m[1].length <= 3
      Date.new(year, m[2].to_i, m[3].to_i)
    rescue Date::Error
      nil
    end

    # 金額：去除 NT$、$、元、千分位、空白後為 ≥ 0、最多 2 位小數、不超過上限的數字。
    def money(value)
      number = decimal(value)
      number if number && number >= 0 && number <= MAX_MONEY && number == number.round(2)
    end

    # 一般數字（數量、單價），不限小數位；可為負數，由呼叫端判斷範圍。
    def decimal(value)
      raw =
        case value
        when Integer then value.to_s
        # 公式算出的浮點數會帶誤差（例：1102.5000000000002），先收斂再判斷小數位
        when Float   then value.round(10).to_s
        when String then value.gsub(/NT\$|\$|元|[,，\s]/i, "")
        end
      return nil unless raw&.match?(/\A-?\d+(\.\d+)?\z/)
      BigDecimal(raw)
    end

    # 統一編號：8 碼數字且通過檢查碼。數字儲存格會吃掉開頭的 0，補回 8 碼。
    def tax_id(value)
      raw = value.is_a?(Numeric) ? text(value).rjust(8, "0") : text(value).to_s.delete(" -")
      raw if raw.match?(/\A\d{8}\z/) && tax_id_checksum?(raw)
    end

    # 財政部 2023 年起的檢查碼規則（相容舊規則）：各位數乘權重後取各位數字相加，
    # 總和可被 5 整除即通過；第 7 碼為 7 時，總和 + 1 可被 5 整除也算通過。
    def tax_id_checksum?(digits)
      sum = digits.chars.each_with_index.sum do |ch, i|
        product = ch.to_i * TAX_ID_WEIGHTS[i]
        product / 10 + product % 10
      end
      (sum % 5).zero? || (digits[6] == "7" && ((sum + 1) % 5).zero?)
    end

    # 發票號碼：2 碼英文字母 + 8 碼數字（可有 -），統一存成 AB-12345678（同手動新增）。
    def invoice_no(value)
      m = text(value).to_s.upcase.delete(" ").match(/\A([A-Z]{2})-?(\d{8})\z/)
      m && "#{m[1]}-#{m[2]}"
    end
  end
end
