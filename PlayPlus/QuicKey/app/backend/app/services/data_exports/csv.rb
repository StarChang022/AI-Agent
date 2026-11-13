require "csv"

module DataExports
  # 匯出 CSV 的欄位與格式（PRD 第 24 條、docs/dev/data-export-api.md 第 7 節）。
  # 日期 YYYY-MM-DD、金額為數字；代墊款欄位沿用「全部紀錄」頁原本 CSV 匯出的欄位，另加品項、圖檔。
  module Csv
    BOM = "\xEF\xBB\xBF".b.freeze

    DOCUMENT_TYPE_LABELS = { "invoice" => "發票", "receipt" => "收據" }.freeze
    TAX_RATE_LABELS      = { "business_5" => "應稅", "exempt_0" => "免稅" }.freeze
    PAYOUT_LABELS        = { "pending" => "待付款", "paid" => "已付款" }.freeze
    COLLECTION_LABELS    = { "uncollected" => "待收款", "collected" => "已收款" }.freeze
    SOURCE_LABELS        = { "general" => "一般支出", "reimbursement" => "代墊款", "transfer_fee" => "移轉手續費" }.freeze

    # 需要跟前端 constants/expense.ts STATUS_LABELS 對齊。
    REIMBURSEMENT_STATUS_LABELS = {
      "draft"     => "草稿",
      "in_review" => "簽核中",
      "rejected"  => "駁回",
      "approved"  => "已核銷",
      "paid"      => "已發放",
      "voided"    => "已作廢"
    }.freeze

    EXPENSE_HEADERS = %w[
      發生日期 發票日期 應付日期 實付日期 文件類型 賣方 統一編號 發票號碼 類別 帳戶 稅別
      未稅金額 稅額 含稅金額 付款狀態 來源 說明 品項 圖檔
    ].freeze

    INCOME_HEADERS = %w[
      發生日期 發票日期 應收日期 實收日期 文件類型 客戶 統一編號 發票號碼 類別 帳戶 稅別
      未稅金額 稅額 含稅金額 收款狀態 說明 品項 圖檔
    ].freeze

    REIMBURSEMENT_HEADERS = %w[申請人 說明 類別 金額 發生日期 發票日期 狀態 建立時間].freeze

    HEADERS = {
      "expense"       => EXPENSE_HEADERS,
      "income"        => INCOME_HEADERS,
      "reimbursement" => REIMBURSEMENT_HEADERS + %w[品項 圖檔]
    }.freeze

    # 以 = + - @ 或 Tab、換行開頭的文字，Excel 開啟 CSV 時會當成公式執行；前面加 ' 讓它
    # 顯示成純文字。
    FORMULA_PREFIX = /\A[=+\-@\t\r]/

    module_function

    # 一行一行產生（第一行前加 BOM，Excel 直接開啟中文不亂碼），邊讀邊寫檔或邊輸出給瀏覽器，
    # 不必先組出整份。rows 可以是陣列或 Enumerator。
    def lines(headers, rows)
      Enumerator.new do |y|
        y << BOM + ::CSV.generate_line(headers).b
        rows.each { |row| y << ::CSV.generate_line(row.map { |v| safe(v) }).b }
      end
    end

    def safe(value)
      value.is_a?(String) && value.match?(FORMULA_PREFIX) ? "'#{value}" : value
    end

    # type：expense / income / reimbursement；files：該筆在 ZIP 內的檔名陣列。
    def row(type, record, files)
      case type
      when "expense"       then expense_row(record, files)
      when "income"        then income_row(record, files)
      when "reimbursement" then reimbursement_row(record) + [ items(record.items), join(files) ]
      end
    end

    def expense_row(e, files)
      [
        e.date&.iso8601, e.invoice_date&.iso8601, e.planned_payout_date&.iso8601, e.paid_at&.iso8601,
        DOCUMENT_TYPE_LABELS[e.document_type], e.vendor, e.tax_id, e.invoice_no,
        e.category&.name, e.account&.name, TAX_RATE_LABELS[e.tax_rate],
        e.pre_tax_amt&.to_f, e.tax_amt&.to_f, e.amount&.to_f,
        PAYOUT_LABELS[e.payout_status], expense_source(e), e.note, items(e.items), join(files)
      ]
    end

    def income_row(i, files)
      [
        i.date&.iso8601, i.invoice_date&.iso8601, i.planned_collection_date&.iso8601, i.collected_at&.iso8601,
        DOCUMENT_TYPE_LABELS[i.document_type], i.customer, i.tax_id, i.invoice_no,
        i.category&.name, i.account&.name, TAX_RATE_LABELS[i.tax_rate],
        i.pre_tax_amt&.to_f, i.tax_amt&.to_f, i.amount&.to_f,
        COLLECTION_LABELS[i.collection_status], i.note, items(i.items), join(files)
      ]
    end

    # REIMBURSEMENT_HEADERS 的欄位（不含圖檔）。
    def reimbursement_row(r)
      [
        r.employee&.name,
        r.description,
        r.category&.name,
        r.amount&.to_f,
        r.incurred_at&.iso8601,
        r.invoice_date&.iso8601,
        REIMBURSEMENT_STATUS_LABELS[r.status] || r.status,
        r.created_at.iso8601
      ]
    end

    # 固定紀錄的 source 仍是 general，以 recurring_period 判斷。
    def expense_source(e)
      return "固定" if e.source == "general" && e.recurring_period.present?
      SOURCE_LABELS[e.source]
    end

    # 品項合併一欄：「A4 紙 2 × 150 = 300；碳粉 1 × 900 = 900」。
    def items(list)
      Array(list).map do |item|
        name = item["name"].to_s.strip
        qty, price, subtotal = item.values_at("quantity", "unit_price", "subtotal").map { |v| number(v) }
        math = qty && price ? "#{qty} × #{price}" : nil
        math = [ math, subtotal ].compact.join(" = ").presence
        [ name.presence, math ].compact.join(" ")
      end.compact_blank.join("；").presence
    end

    def number(value)
      return nil if value.blank?
      d = BigDecimal(value.to_s)
      d.frac.zero? ? d.to_i.to_s : d.to_s("F")
    rescue ArgumentError
      value.to_s
    end

    def join(files)
      Array(files).join("；").presence
    end
  end
end
