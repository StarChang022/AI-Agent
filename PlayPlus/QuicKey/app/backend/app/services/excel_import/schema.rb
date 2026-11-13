module ExcelImport
  # Excel 匯入的欄位定義（docs/資料模型.md §5.4）。範本產生（TemplateBuilder）與解析
  # （ColumnMapper / Parser）共用這一份，避免範本標題與解析規則不一致。
  #
  # required：
  # - :value  標題必須存在，且值必填（範本標題加 *）
  # - :header 標題必須存在，值依條件必填（統編：支出發票必填；發票號碼：發票必填；未稅、含稅至少填一個）
  # - nil     標題可缺，缺少時視為該欄全空
  class Schema
    Field = Data.define(:key, :header, :section, :required, :hint)

    MASTER_KEYS = %i[
      date invoice_date document_type party tax_id invoice_no category account
      tax_rate pre_tax_amt tax_amt amount planned_date status settled_at note
    ].freeze
    ITEM_KEYS = %i[item_name item_quantity item_unit_price item_subtotal].freeze

    attr_reader :kind, :label, :fields, :status_words, :default_status, :settled_status

    def self.for(kind)
      case kind.to_s
      when "expense" then EXPENSE
      when "income"  then INCOME
      end
    end

    def initialize(kind:, label:, fields:, status_words:, default_status:, settled_status:)
      @kind           = kind
      @label          = label
      @fields         = fields.freeze
      @status_words   = status_words.freeze
      @default_status = default_status
      @settled_status = settled_status
    end

    def field(key)
      fields.find { |f| f.key == key }
    end

    def header(key)
      field(key).header
    end

    # 範本標題：必填值加 *（解析時會忽略 *）。
    def template_header(field)
      field.required == :value ? "#{field.header}*" : field.header
    end

    def status_label(status)
      status_words.key(status)
    end

    def self.build(kind:, label:, party:, tax_id_hint:, planned_date:, planned_hint:, status:, settled_at:, status_words:, default_status:, settled_status:)
      new(
        kind: kind, label: label, status_words: status_words,
        default_status: default_status, settled_status: settled_status,
        fields: [
          Field.new(:doc_ref,         "單據編號", :group,  nil,     "同一張單據有多個品項時，每列填相同編號；只有一列的單據可留空。編號只用來分組，不會存入系統"),
          Field.new(:date,            "發生日期", :master, :header, "收據必填；發票空白時帶入發票日期。例：2026/10/29、2026-10-29、民國 115/10/29"),
          Field.new(:invoice_date,    "發票日期", :master, :header, "發票必填，寫法同發生日期；收據不填"),
          Field.new(:document_type,   "文件類型", :master, :value,  "必填，填發票或收據"),
          Field.new(:party,           party,      :master, :value,  "必填"),
          Field.new(:tax_id,          "統一編號", :master, :header, tax_id_hint),
          Field.new(:invoice_no,      "發票號碼", :master, :header, "發票必填，2 碼英文字母 + 8 碼數字，例：AB-12345678；收據不填"),
          Field.new(:category,        "類別",     :master, :value,  "必填。填類別名稱；系統找不到的名稱，會在預覽時請你對應到既有類別或新增"),
          Field.new(:account,         "帳戶",     :master, nil,     "填帳戶名稱；空白時帶入上一次使用的帳戶。系統找不到的名稱，會在預覽時請你對應到既有帳戶"),
          Field.new(:tax_rate,        "稅別",     :master, nil,     "發票填應稅或免稅，空白視為應稅；收據一律免稅"),
          Field.new(:pre_tax_amt,     "未稅金額", :master, :header, "未稅金額、含稅金額至少填一個，另一個依稅別推算；可含 NT$、$、元、千分位"),
          Field.new(:tax_amt,         "稅額",     :master, nil,     "可空白，系統依未稅、含稅金額計算；收據為 0"),
          Field.new(:amount,          "含稅金額", :master, :header, "未稅金額、含稅金額至少填一個；兩個都填時照填"),
          Field.new(:planned_date,    planned_date, :master, nil,   "選填，寫法同發生日期；#{planned_hint}"),
          Field.new(:status,          status,     :master, nil,     "#{status_words.keys.join('或')}；空白視為#{status_words.key(default_status)}"),
          Field.new(:settled_at,      settled_at, :master, nil,     "#{status_words.key(settled_status)}時填寫，寫法同發生日期；空白以發生日期代入"),
          Field.new(:note,            "說明",     :master, nil,     "選填"),
          Field.new(:item_name,       "品名",     :item,   nil,     "選填，每列一個品項；沒有品項時品項四欄都留空。品項不會代替金額"),
          Field.new(:item_quantity,   "數量",     :item,   nil,     "空白視為 1，需大於 0"),
          Field.new(:item_unit_price, "單價",     :item,   nil,     "只填小計時，單價 = 小計 ÷ 數量"),
          Field.new(:item_subtotal,   "小計",     :item,   nil,     "空白時 = 數量 × 單價")
        ]
      )
    end

    EXPENSE = build(
      kind: "expense", label: "支出",
      party: "廠商", tax_id_hint: "發票必填，8 碼數字；收據選填",
      planned_date: "應付日期", planned_hint: "空白時依公司付款日，從匯入當天往後找最近的付款日；關閉付款日時為發生日期",
      status: "付款狀態", settled_at: "實付日期",
      status_words: { "待付款" => "pending", "已付款" => "paid" },
      default_status: "pending", settled_status: "paid"
    )

    INCOME = build(
      kind: "income", label: "收入",
      party: "客戶", tax_id_hint: "選填，8 碼數字（開給個人的發票沒有買方統編）",
      planned_date: "應收日期", planned_hint: "空白時為發生日期",
      status: "收款狀態", settled_at: "實收日期",
      status_words: { "待收款" => "uncollected", "已收款" => "collected" },
      default_status: "uncollected", settled_status: "collected"
    )
  end
end
