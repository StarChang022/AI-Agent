require "axlsx"

module ExcelImport
  # 匯入範本 .xlsx：第一個工作表為填寫區（只有標題列，解析時讀第一個工作表），
  # 第二個工作表「填寫說明」列出各欄寫法，並示範多品項、無品項、不填單據編號三種寫法。
  # 標題與說明都取自 Schema，和解析共用同一份定義。
  class TemplateBuilder
    EXAMPLES = {
      "expense" => [
        { doc_ref: "A001", date: "2026/10/29", invoice_date: "2026/10/29", document_type: "發票",
          party: "大同文具行", tax_id: "04595257", planned_date: "2026/11/25",
          invoice_no: "AB-12345678", category: "文具用品", account: "零用金", tax_rate: "應稅", amount: 450,
          item_name: "A4 影印紙", item_quantity: 2, item_unit_price: 150, item_subtotal: 300 },
        { doc_ref: "A001", item_name: "原子筆", item_quantity: 10, item_unit_price: 15, item_subtotal: 150 },
        { date: "2026/10/30", document_type: "收據", party: "台灣高鐵", category: "交通費", amount: 1490,
          status: "已付款", settled_at: "2026/11/05", note: "客戶拜訪" },
        { date: "2026/10/31", document_type: "收據", party: "便當店", category: "伙食費", amount: 500,
          item_name: "便當", item_quantity: 5, item_unit_price: 100 }
      ],
      "income" => [
        { doc_ref: "S001", date: "2026/10/29", invoice_date: "2026/10/31", document_type: "發票",
          party: "好客股份有限公司", tax_id: "04595257", planned_date: "2026/11/28",
          invoice_no: "AB-12345678", category: "銷售收入", account: "零用金", tax_rate: "應稅", pre_tax_amt: 3200,
          item_name: "商品 A", item_quantity: 3, item_unit_price: 1000, item_subtotal: 3000 },
        { doc_ref: "S001", item_name: "運費", item_quantity: 1, item_unit_price: 200, item_subtotal: 200 },
        { date: "2026/10/30", document_type: "收據", party: "王小姐", category: "服務收入", amount: 5000,
          status: "已收款", settled_at: "2026/11/05", note: "顧問費" },
        { date: "2026/10/31", document_type: "收據", party: "陳先生", category: "銷售收入", amount: 1600,
          item_name: "商品 B", item_quantity: 2, item_unit_price: 800 }
      ]
    }.freeze

    def initialize(schema)
      @schema = schema
    end

    def to_xlsx
      package = Axlsx::Package.new
      wb = package.workbook
      bold = wb.styles.add_style(b: true)

      wb.add_worksheet(name: "#{@schema.label}資料") do |sheet|
        sheet.add_row @schema.fields.map { |f| @schema.template_header(f) }, style: bold
      end

      wb.add_worksheet(name: "填寫說明") do |sheet|
        sheet.add_row [ "填寫方式" ], style: bold
        sheet.add_row [ "在第一個工作表「#{@schema.label}資料」由第 2 列開始填寫，一列一個品項。標題名稱請勿修改，欄位順序可調換。" ]
        sheet.add_row [ "同一張單據有多個品項時，每列填相同的單據編號；單據的#{@schema.header(:date)}、#{@schema.header(:party)}、類別、金額等資料填在第一列即可。" ]
        sheet.add_row [ "標題有 * 的欄位必填；發票另需發票日期、統一編號與發票號碼（發生日期空白時帶入發票日期）；收據需填發生日期；未稅金額、含稅金額至少填一個。必填欄位空白或無效的單據不會匯入。" ]
        sheet.add_row [ "每次最多 1,000 列、檔案 5 MB 以內。" ]
        sheet.add_row []
        sheet.add_row [ "欄位", "必填", "寫法" ], style: bold
        @schema.fields.each do |f|
          sheet.add_row [ f.header, f.required == :value ? "必填" : "", f.hint ]
        end
        sheet.add_row []
        sheet.add_row [ "範例（依序為：多品項、無品項、不填單據編號）" ], style: bold
        sheet.add_row @schema.fields.map { |f| @schema.template_header(f) }, style: bold
        EXAMPLES.fetch(@schema.kind).each do |example|
          sheet.add_row @schema.fields.map { |f| example[f.key] }, types: @schema.fields.map { :string }
        end
      end

      package.to_stream.read
    end
  end
end
