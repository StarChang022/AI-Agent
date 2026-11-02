require "test_helper"
require "axlsx"

# Excel 匯入（docs/資料模型.md §5.4）：金額推算與上限、分組、必填欄位不匯入與補預設值
# 的判斷、類別只比對本公司、預覽時移除、交易整批回滾、壞檔與資源上限、權限。
class ExcelImportTest < ActionDispatch::IntegrationTest
  # 讓指定金額的支出存檔失敗，用來驗證整批回滾。error 為 :db 時模擬資料庫錯誤。
  module FailingSave
    mattr_accessor :amount, :error, instance_accessor: false

    def save!(**)
      if FailingSave.amount && amount == FailingSave.amount
        raise ActiveRecord::StatementInvalid, "測試失敗" if FailingSave.error == :db
        errors.add(:amount, "測試失敗")
        raise ActiveRecord::RecordInvalid, self
      end
      super
    end
  end
  Expense.prepend(FailingSave)

  EXPENSE_HEADERS = ExcelImport::Schema::EXPENSE.fields.map(&:header)
  INCOME_HEADERS  = ExcelImport::Schema::INCOME.fields.map(&:header)

  # 一筆合格的收據；測試只覆寫要測的欄位（值給 nil = 清空該欄）
  RECEIPT = { "日期" => "2026/10/1", "文件類型" => "收據", "廠商" => "甲", "類別" => "交通費", "帳戶" => "主帳戶", "含稅金額" => 100 }.freeze
  INVOICE = RECEIPT.merge("文件類型" => "發票", "統一編號" => "04595257", "發票號碼" => "AB-12345678").freeze

  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @account = create_account(company: @company, name: "主帳戶", opening_month: Date.new(2020, 1, 1))
    @tmpfiles = []
  end

  teardown do
    @tmpfiles.each(&:close!)
  end

  # ─── 範本 ─────────────────────────────

  test "支出範本：欄位順序與必填標示，且能被解析" do
    headers = template_headers(:expense)
    assert_equal %w[單據編號 日期* 文件類型* 廠商* 統一編號 發票號碼 類別* 帳戶 稅別 未稅金額 稅額 含稅金額
                    付款狀態 付款日 說明 品名 數量 單價 小計], headers
    assert_nothing_raised { ExcelImport::ColumnMapper.map(headers, ExcelImport::Schema::EXPENSE) }
  end

  test "收入範本：標題為收入欄位" do
    headers = template_headers(:income)
    assert_equal [ "開立日*", "文件類型*", "客戶*" ], headers[1, 3]
    assert_equal [ "收款狀態", "收款日" ], headers[12, 2]
  end

  # ─── 金額推算 ─────────────────────────────

  test "收據只填含稅且帶小數 → 未稅等於含稅，稅額為 0" do
    r = preview_one(RECEIPT.merge("含稅金額" => "100.50"))
    assert_equal "ok", r.status
    assert_equal [ BigDecimal("100.5"), 0, BigDecimal("100.5") ], amounts(r)
  end

  test "應稅發票只填含稅 → 推算未稅與稅額" do
    r = preview_one(INVOICE.merge("含稅金額" => "1,050"))
    assert_equal "ok", r.status
    assert_equal [ 1000, 50, 1050 ], amounts(r)
  end

  test "應稅發票只填未稅 → 推算稅額與含稅（四捨五入同手動新增）" do
    a, b = preview_expense([ INVOICE.merge("含稅金額" => nil, "未稅金額" => 1000),
                             INVOICE.merge("含稅金額" => nil, "未稅金額" => "NT$450") ])
    assert_equal [ 1000, 50, 1050 ], amounts(a)
    assert_equal [ 450, 23, 473 ], amounts(b)
  end

  test "兩個都填照填，稅額 = 含稅 − 未稅；與 5% 相差 1 元內、稅額有填且相符不列出" do
    r = preview_one(INVOICE.merge("未稅金額" => 1000, "含稅金額" => 1051, "稅額" => 51))
    assert_equal "ok", r.status
    assert_equal [ 1000, 51, 1051 ], amounts(r)
  end

  test "應稅發票兩個都填但稅額與 5% 相差超過 1 元 → 照填並列出" do
    r = preview_one(INVOICE.merge("未稅金額" => 1000, "含稅金額" => 1060))
    assert_equal "warning", r.status
    assert_equal [ 1000, 60, 1060 ], amounts(r)
    assert_equal "未稅金額與含稅金額不符合 5% 稅率，請確認", r.messages.sole.text
  end

  test "稅額有填但與推算不符 → 以推算為準並列出" do
    r = preview_one(INVOICE.merge("含稅金額" => 1050, "稅額" => 99))
    assert_equal "warning", r.status
    assert_equal [ 1000, 50, 1050 ], amounts(r)
    assert_equal "稅額「99」與推算結果不符，以 50 為準", r.messages.sole.text
  end

  test "應稅發票的未稅大於含稅 → 不匯入" do
    r = preview_one(INVOICE.merge("未稅金額" => 200, "含稅金額" => 100))
    assert_equal "skipped", r.status
    assert_equal "未稅金額大於含稅金額", r.messages.sole.text
  end

  test "免稅發票或收據兩個都填但不相等 → 以含稅為準並列出" do
    exempt, receipt = preview_expense([ INVOICE.merge("稅別" => "免稅", "未稅金額" => 90, "含稅金額" => 100),
                                        RECEIPT.merge("未稅金額" => 90, "含稅金額" => 100) ])
    [ exempt, receipt ].each do |r|
      assert_equal "warning", r.status
      assert_equal [ 100, 0, 100 ], amounts(r)
    end
  end

  test "未稅與含稅都空白或無法判讀 → 不匯入（有品項也不代替）" do
    blank, bad = preview_expense([ RECEIPT.merge("含稅金額" => nil, "品名" => "便當", "小計" => 100),
                                   RECEIPT.merge("含稅金額" => "一百") ])
    assert_equal %w[skipped skipped], [ blank.status, bad.status ]
    assert_equal "未稅金額與含稅金額至少要填一個", blank.messages.sole.text
    assert_equal "含稅金額「一百」無法判讀", bad.messages.sole.text
  end

  test "金額上限 9,999,999,999.99" do
    max_ok, over, derived_over = preview_expense([
      RECEIPT.merge("含稅金額" => "9,999,999,999.99"),
      RECEIPT.merge("含稅金額" => "99999999999999999"),
      INVOICE.merge("含稅金額" => nil, "未稅金額" => "9999999999.99")
    ])
    assert_equal %w[ok skipped skipped], [ max_ok, over, derived_over ].map(&:status)
  end

  # ─── 品項 ─────────────────────────────

  test "品項：小計空白 = 數量 × 單價；只有小計時數量 1；加總與金額不一致列出" do
    r = preview_expense([
      RECEIPT.merge("單據編號" => "A", "含稅金額" => 999, "品名" => "便當", "數量" => 3, "單價" => 100),
      { "單據編號" => "A", "品名" => "飲料", "小計" => 50 }
    ]).first
    assert_equal [ 3, 100, 300 ], r.items[0].values_at(:quantity, :unit_price, :subtotal)
    assert_equal [ 1, 50, 50 ], r.items[1].values_at(:quantity, :unit_price, :subtotal)
    assert_equal 999, r.attrs[:amount]
    assert_equal "品項小計加總 350 與含稅金額 999 不一致", r.messages.sole.text
  end

  test "品項加總等於未稅或含稅任一個即不提醒；都不相等時列出兩個金額" do
    by_pre, by_amount, neither = preview_expense([
      INVOICE.merge("單據編號" => "A", "含稅金額" => 1050, "品名" => "x", "小計" => 1000),
      INVOICE.merge("單據編號" => "B", "含稅金額" => 1050, "品名" => "x", "小計" => 1050),
      INVOICE.merge("單據編號" => "C", "含稅金額" => 1050, "品名" => "x", "小計" => 900)
    ])
    assert_equal %w[ok ok warning], [ by_pre, by_amount, neither ].map(&:status)
    assert_equal "品項小計加總 900 與未稅金額 1000、含稅金額 1050 不一致", neither.messages.sole.text
  end

  test "品名空白、數量 0 或負數、小計超過上限的品項不匯入，主檔照匯入並列出" do
    r = preview_expense([
      RECEIPT.merge("單據編號" => "A", "含稅金額" => 20, "數量" => 1, "單價" => 10),
      { "單據編號" => "A", "品名" => "x", "數量" => 0, "單價" => 10 },
      { "單據編號" => "A", "品名" => "y", "數量" => -2, "單價" => 10 },
      { "單據編號" => "A", "品名" => "z", "數量" => 100000, "單價" => 1000000 },
      { "單據編號" => "A", "品名" => "ok", "數量" => 2, "單價" => 10 }
    ]).first
    assert_equal "warning", r.status
    assert_equal [ "ok" ], r.items.map { |i| i[:name] }
    assert_equal [ 2, 3, 4, 5 ], r.messages.map(&:row)
  end

  # ─── 分組 ─────────────────────────────

  test "單據編號相同的列合併（不需相鄰），空白的列自成一筆；主檔以第一列為準" do
    records = preview_expense([
      RECEIPT.merge("單據編號" => "A1", "品名" => "x", "小計" => 10),
      RECEIPT.merge("廠商" => "乙"),
      RECEIPT.merge("廠商" => "丙"),
      { "單據編號" => "A1", "廠商" => "丁", "品名" => "y", "小計" => 20 }
    ])
    assert_equal [ [ 2, 5 ], [ 3 ], [ 4 ] ], records.map(&:rows)
    grouped = records.first
    assert_equal "甲", grouped.attrs[:party]
    assert_equal 2, grouped.items.size
    assert_includes grouped.messages.map(&:text), "「廠商」與第 2 列不同，以第 2 列為準"
  end

  # ─── 必填欄位 ─────────────────────────────

  test "日期、文件類型、廠商空白或無效 → 不匯入" do
    cases = {
      { "日期" => nil }            => "日期未填",
      { "日期" => "1999/1/1" }     => "日期「1999/1/1」無法判讀",
      { "文件類型" => nil }        => "文件類型未填",
      { "文件類型" => "收據單" }   => "文件類型「收據單」無法判讀，請填發票或收據",
      { "廠商" => nil }            => "廠商未填"
    }
    records = preview_expense(cases.keys.map { |c| RECEIPT.merge(c) })
    assert_equal [ "skipped" ] * cases.size, records.map(&:status)
    assert_equal cases.values, records.map { |r| r.messages.sole.text }
  end

  test "收入的客戶空白 → 不匯入" do
    row = { "開立日" => "2026/10/1", "文件類型" => "收據", "類別" => "銷售收入", "帳戶" => "主帳戶", "含稅金額" => 1 }
    r = preview(:income, INCOME_HEADERS, [ row ]).records.sole
    assert_equal "skipped", r.status
    assert_equal "客戶未填", r.messages.sole.text
  end

  test "發票的統一編號、發票號碼空白或無效 → 不匯入（不再改成收據）" do
    cases = {
      { "統一編號" => nil }          => "發票須填統一編號",
      { "統一編號" => "12345678" }   => "統一編號「12345678」格式不正確",
      { "發票號碼" => nil }          => "發票須填發票號碼",
      { "發票號碼" => "A1234" }      => "發票號碼「A1234」格式不正確"
    }
    records = preview_expense(cases.keys.map { |c| INVOICE.merge(c) })
    assert_equal [ "skipped" ] * cases.size, records.map(&:status)
    assert_equal cases.values, records.map { |r| r.messages.sole.text }
  end

  test "有效發票：統編數字儲存格補回開頭 0、發票號碼統一格式" do
    r = preview_one(INVOICE.merge("統一編號" => 4595257, "發票號碼" => "ab12345678"))
    assert_equal "ok", r.status
    assert_equal [ "invoice", "04595257", "AB-12345678", "business_5" ],
      r.attrs.values_at(:document_type, :tax_id, :invoice_no, :tax_rate)
  end

  test "收據：統編無效不帶入、發票號碼不帶入、填了應稅改免稅，都列出" do
    r = preview_one(RECEIPT.merge("統一編號" => "12345678", "發票號碼" => "AB-12345678", "稅別" => "應稅", "稅額" => 5))
    assert_equal "warning", r.status
    assert_equal [ "receipt", nil, nil, "exempt_0" ], r.attrs.values_at(:document_type, :tax_id, :invoice_no, :tax_rate)
    assert_equal [ 100, 0, 100 ], amounts(r)
    assert_equal [ "統一編號「12345678」格式不正確，未帶入", "收據不需要發票號碼，「AB-12345678」未帶入",
                   "收據一律免稅，稅別「應稅」已改為免稅", "稅額「5」與推算結果不符，以 0 為準" ], r.messages.map(&:text)
  end

  test "空白套預設值不列出；有填但看不懂才列出" do
    blank, unreadable = preview_expense([ RECEIPT, INVOICE.merge("稅別" => "營業稅10%", "付款狀態" => "不知道") ])
    assert_equal "ok", blank.status
    assert_equal [ "exempt_0", "pending" ], blank.attrs.values_at(:tax_rate, :status)
    assert_equal "warning", unreadable.status
    assert_equal [ "business_5", "pending" ], unreadable.attrs.values_at(:tax_rate, :status)
    assert_equal 2, unreadable.messages.size
  end

  test "已付款但付款日空白 → 以日期代入並列出；待付款卻填付款日 → 不帶入並列出" do
    paid, pending = preview_expense([ RECEIPT.merge("付款狀態" => "已付款"), RECEIPT.merge("付款日" => "2026/10/5") ])
    assert_equal [ Date.new(2026, 10, 1), nil ], [ paid.attrs[:settled_at], pending.attrs[:settled_at] ]
    assert_equal %w[warning warning], [ paid.status, pending.status ]
  end

  test "接受民國年、Excel 日期與 - 分隔" do
    records = preview_expense([ "115/10/29", Date.new(2026, 10, 29), "2026-10-29" ].map { |d| RECEIPT.merge("日期" => d) })
    assert_equal [ Date.new(2026, 10, 29) ] * 3, records.map { |r| r.attrs[:date] }
  end

  # ─── 帳戶 ─────────────────────────────

  test "帳戶有填用檔內的；空白帶上一次使用的帳戶；同一份混合時各列分別處理" do
    other = create_account(company: @company, name: "零用金")
    create_expense_with(other)

    post_import(:expense, [ RECEIPT.merge("含稅金額" => 1), RECEIPT.merge("含稅金額" => 2, "帳戶" => nil) ])
    assert_response :created
    assert_equal @account.id, @company.expenses.find_by!(amount: 1).account_id
    assert_equal other.id, @company.expenses.find_by!(amount: 2).account_id
  end

  test "帳戶比對不分大小寫" do
    create_account(company: @company, name: "Cash")
    assert_equal "Cash", preview_one(RECEIPT.merge("帳戶" => "cash")).account.name
  end

  test "帳戶找不到、在垃圾桶或屬於別家公司 → 可匯入，列入帳戶對應清單；名稱不分大小寫只問一次" do
    create_account(company: @company, name: "已刪除").discard!
    create_account(company: create_company(name: "別家"), name: "別家帳戶")

    rows = [ RECEIPT.merge("帳戶" => "Bank"), RECEIPT.merge("帳戶" => "bank"), RECEIPT.merge("帳戶" => "已刪除"),
             RECEIPT.merge("帳戶" => "別家帳戶"), RECEIPT.merge("帳戶" => "沒用到", "廠商" => nil) ]
    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, rows))
    assert_response :ok

    body = response.parsed_body
    assert_equal 4, body.dig("counts", "importable")
    assert_equal [ "Bank", "bank", "已刪除", "別家帳戶", nil ], body["records"].map { |r| r.dig("summary", "account_name") }
    assert_equal [
      { "name" => "Bank", "rows" => [ 2, 3 ], "state" => "missing" },
      { "name" => "已刪除", "rows" => [ 4 ], "state" => "discarded" },
      { "name" => "別家帳戶", "rows" => [ 5 ], "state" => "missing" }
    ], body["accounts"]
  end

  test "帳戶對應：對應到既有帳戶後寫入該帳戶" do
    petty = create_account(company: @company, name: "零用金")
    post_import(:expense, [ RECEIPT.merge("帳戶" => "銀行", "含稅金額" => 1), RECEIPT.merge("含稅金額" => 2) ],
                account_mapping: { "銀行" => petty.id })
    assert_response :created
    assert_equal petty.id, @company.expenses.find_by!(amount: 1).account_id
    assert_equal @account.id, @company.expenses.find_by!(amount: 2).account_id
  end

  test "帳戶對應：沒選 → 422；對應到垃圾桶或別家帳戶 → 409 請重新預覽；都不建立" do
    row = RECEIPT.merge("帳戶" => "銀行")
    post_import(:expense, [ row ])
    assert_response :unprocessable_content
    assert_equal "INVALID_ACCOUNT_MAPPING", response.parsed_body["error"]
    assert_equal "請選擇帳戶「銀行」要對應到哪個帳戶", response.parsed_body["message"]

    trashed = create_account(company: @company, name: "已刪除")
    trashed.discard!
    foreign = create_account(company: create_company(name: "別家"))
    [ trashed.id, foreign.id, "not-a-uuid" ].each do |id|
      post_import(:expense, [ row ], account_mapping: { "銀行" => id })
      assert_response :conflict
      assert_equal "ACCOUNT_CHANGED", response.parsed_body["error"]
      assert_equal "帳戶已變更，請重新預覽", response.parsed_body["message"]
    end
    assert_equal 0, @company.expenses.count
  end

  test "帳戶對應：只被移除的單據用到的名稱不用對應；格式錯誤 → 422" do
    rows = [ RECEIPT.merge("含稅金額" => 1), RECEIPT.merge("帳戶" => "銀行", "含稅金額" => 2) ]
    post_import(:expense, rows, excluded_rows: [ 3 ])
    assert_response :created
    assert_equal [ 1 ], @company.expenses.pluck(:amount)

    post "/api/expenses/import", headers: auth_headers(@admin),
      params: { file: xlsx(EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, [ RECEIPT ])), account_mapping: "不是 JSON" }
    assert_response :unprocessable_content
    assert_equal "INVALID_ACCOUNT_MAPPING", response.parsed_body["error"]
  end

  test "帳戶空白且沒有上一次使用的帳戶 → 不匯入" do
    r = preview_one(RECEIPT.merge("帳戶" => nil))
    assert_equal "skipped", r.status
    assert_equal "帳戶未填，且沒有上一次使用的帳戶", r.messages.sole.text
  end

  test "公司沒有任何帳戶 → 預覽與匯入都整份退回，提示先建立帳戶" do
    @account.discard!

    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, [ RECEIPT ]))
    assert_response :unprocessable_content
    assert_equal "NO_ACCOUNTS", response.parsed_body["error"]
    assert_equal "公司還沒有帳戶，請先到帳戶設定建立", response.parsed_body["message"]

    post_import(:expense, [ RECEIPT ])
    assert_response :unprocessable_content
    assert_equal "NO_ACCOUNTS", response.parsed_body["error"]
    assert_equal 0, @company.expenses.count
  end

  test "付款日早於起始月份：帳戶已確定的列在預覽提示；照常匯入，完成畫面回傳筆數含對應帳戶的列" do
    late = create_account(company: @company, name: "新帳戶", opening_month: Date.current.beginning_of_month)
    early = { "付款狀態" => "已付款", "付款日" => "2026/1/5" }
    rows = [
      RECEIPT.merge(early).merge("帳戶" => "新帳戶", "含稅金額" => 1), # 帳戶已確定：早於起始月份
      RECEIPT.merge(early).merge("帳戶" => "主帳戶", "含稅金額" => 2), # 不早於起始月份
      RECEIPT.merge(early).merge("帳戶" => "銀行", "含稅金額" => 3),   # 對應到 late：早於起始月份
      RECEIPT.merge("帳戶" => "新帳戶", "含稅金額" => 4)                # 待付款不受影響
    ]

    records = preview_expense(rows)
    assert_equal "warning", records[0].status
    assert_equal "付款日早於帳戶「新帳戶」的起始月份，不計入現金流", records[0].messages.sole.text
    assert_equal "ok", records[3].status

    post_import(:expense, rows, account_mapping: { "銀行" => late.id })
    assert_response :created
    assert_equal 4, response.parsed_body["created_count"]
    assert_equal 2, response.parsed_body["outside_cash_flow_count"]
  end

  test "預覽回傳每筆會用的帳戶名稱，不匯入的筆數為空" do
    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, [ RECEIPT, RECEIPT.merge("廠商" => nil) ]))
    assert_response :ok
    assert_equal [ "主帳戶", nil ], response.parsed_body["records"].map { |r| r.dig("summary", "account_name") }
  end

  test "預覽每筆有獨立欄位標示不計入現金流：帳戶已確定才有 true／false，未確定與不匯入為 null" do
    create_account(company: @company, name: "新帳戶", opening_month: Date.current.beginning_of_month)
    early = { "付款狀態" => "已付款", "付款日" => "2026/1/5" }
    rows = [
      RECEIPT.merge(early).merge("帳戶" => "新帳戶"),               # 早於起始月份
      RECEIPT.merge(early).merge("帳戶" => "主帳戶"),               # 不早於
      RECEIPT.merge("帳戶" => "新帳戶"),                            # 待付款不受影響
      RECEIPT.merge(early).merge("帳戶" => "銀行"),                 # 帳戶還要對應
      RECEIPT.merge(early).merge("帳戶" => "新帳戶", "廠商" => nil)  # 不匯入
    ]
    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, rows))
    assert_response :ok
    assert_equal [ true, false, false, nil, nil ],
      response.parsed_body["records"].map { |r| r.dig("summary", "outside_cash_flow") }
  end

  test "匯入途中帳戶被刪除 → 409 請重新預覽，整批不建立" do
    # 解析後、寫入前帳戶才被刪：模擬方式是讓解析結果沿用刪除前取到的帳戶
    original = ExcelImport::Parser.instance_method(:parse)
    account  = @account
    ExcelImport::Parser.define_method(:parse) do |*args, **kwargs|
      original.bind_call(self, *args, **kwargs).tap { account.discard! }
    end

    post_import(:expense, [ RECEIPT ])
    assert_response :conflict
    assert_equal "ACCOUNT_CHANGED", response.parsed_body["error"]
    assert_equal "帳戶已變更，請重新預覽", response.parsed_body["message"]
    assert_equal 0, @company.expenses.count
  ensure
    ExcelImport::Parser.define_method(:parse, original)
  end

  test "匯入舊年度已付款：各帳戶隔年期初正確，不管列的順序" do
    other     = create_account(company: @company, name: "第二帳戶", opening_amount: 100, opening_month: Date.new(2020, 1, 1))
    this_year = Date.current.year
    last_year = "#{this_year - 1}/6/1"
    paid = { "付款狀態" => "已付款", "付款日" => last_year, "日期" => last_year }
    rows = %w[第二帳戶 主帳戶 第二帳戶 主帳戶].each_with_index.map do |name, i|
      RECEIPT.merge(paid).merge("帳戶" => name, "含稅金額" => i + 1)
    end

    post_import(:expense, rows)
    assert_response :created

    assert_equal(-6.0, opening_cash_of(@account, this_year))
    assert_equal 96.0, opening_cash_of(other, this_year)
  end

  # ─── 標題與檔案 ─────────────────────────────

  test "缺必要標題整份退回；其他標題缺少視為全空" do
    required = %w[日期 文件類型 廠商 統一編號 發票號碼 類別 未稅金額 含稅金額]
    post_preview(:expense, required - [ "文件類型" ], [ [ "2026/10/1" ] ])
    assert_response :unprocessable_content
    assert_equal "MISSING_COLUMN", response.parsed_body["error"]
    assert_equal "找不到「文件類型」欄，請使用範本", response.parsed_body["message"]

    create_expense_with(@account) # 舊範本沒有帳戶欄：帶上一次使用的帳戶
    post_preview(:expense, required.map { |h| " #{h}* " }, rows_for(required, [ RECEIPT ]))
    assert_response :ok
    assert_equal 1, response.parsed_body.dig("counts", "importable")
  end

  test "沒有資料列整份退回" do
    post_preview(:expense, EXPENSE_HEADERS, [])
    assert_response :unprocessable_content
    assert_equal "NO_DATA_ROWS", response.parsed_body["error"]
  end

  test "內容不是 xlsx、或 zip 裡沒有工作表 → 無法讀取" do
    text = Tempfile.new([ "fake", ".xlsx" ]).tap { |f| @tmpfiles << f }
    text.write("這不是 Excel")
    text.flush
    post_file(text.path)
    assert_response :unprocessable_content
    assert_equal "UNREADABLE_FILE", response.parsed_body["error"]

    zip = Tempfile.new([ "broken", ".xlsx" ]).tap { |f| @tmpfiles << f }
    Zip::OutputStream.open(zip.path) { |z| z.put_next_entry("hello.txt"); z.write("hi") }
    post_file(zip.path)
    assert_response :unprocessable_content
    assert_equal "UNREADABLE_FILE", response.parsed_body["error"]
  end

  test "解壓後過大 → 退回" do
    zip = Tempfile.new([ "bomb", ".xlsx" ]).tap { |f| @tmpfiles << f }
    Zip::OutputStream.open(zip.path) do |z|
      z.put_next_entry("xl/sharedStrings.xml")
      z.write("0" * (ExcelImport::SheetReader::MAX_UNZIPPED_BYTES + 1))
    end
    post_file(zip.path)
    assert_response :unprocessable_content
    assert_equal "FILE_TOO_LARGE", response.parsed_body["error"]
  end

  test "實體列號超過上限 → 退回" do
    rows = Array.new(ExcelImport::SheetReader::MAX_ROW_NUMBER - 1) { [] } + rows_for(EXPENSE_HEADERS, [ RECEIPT ])
    post_preview(:expense, EXPENSE_HEADERS, rows)
    assert_response :unprocessable_content
    assert_equal "TOO_MANY_ROWS", response.parsed_body["error"]
  end

  # ─── 類別 ─────────────────────────────

  test "類別只比對本公司啟用中的同類型類別" do
    other = create_company(name: "別家公司")
    other.categories.create!(kind: "expense", name: "別家專屬", sort_order: 99)
    @company.categories.find_by!(kind: "expense", name: "交際費").update!(is_archived: true)

    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, [
      RECEIPT, RECEIPT.merge("類別" => "別家專屬"), RECEIPT.merge("類別" => "交際費"),
      RECEIPT.merge("類別" => "銷售收入"), RECEIPT.merge("類別" => nil), RECEIPT.merge("類別" => nil)
    ]))
    assert_response :ok
    categories = response.parsed_body["categories"].to_h { |c| [ c["name"], c.values_at("state", "rows", "creatable") ] }
    assert_equal({
      "別家專屬" => [ "missing", [ 3 ], true ],
      "交際費"   => [ "archived", [ 4 ], false ],
      "銷售收入" => [ "missing", [ 5 ], true ],
      ""         => [ "blank", [ 6, 7 ], false ]
    }, categories)
  end

  test "匯入：新增、重新啟用、對應既有類別，並寫稽核日誌與預計付款日" do
    archived = @company.categories.find_by!(kind: "expense", name: "交際費")
    archived.update!(is_archived: true)
    meal = @company.categories.find_by!(kind: "expense", name: "伙食費")

    post_import(:expense, [
      RECEIPT.merge("類別" => "新類別", "含稅金額" => 1),
      RECEIPT.merge("類別" => "交際費", "含稅金額" => 2),
      RECEIPT.merge("類別" => nil, "含稅金額" => 3, "付款狀態" => "已付款", "付款日" => "2026/10/5"),
      RECEIPT.merge("日期" => "壞掉", "含稅金額" => 4)
    ], category_mapping: { "" => meal.id })
    assert_response :created
    body = response.parsed_body
    assert_equal [ 3, 0 ], body.values_at("created_count", "excluded_count")
    assert_equal [ "新類別" ], body["created_categories"].map { |c| c["name"] }
    assert_equal [ archived.id ], body["reactivated_categories"].map { |c| c["id"] }
    assert_equal [ [ 5 ] ], body["skipped"].map { |s| s["rows"] }
    refute archived.reload.is_archived

    paid = @company.expenses.find_by!(amount: 3)
    assert_equal [ meal.id, "paid", Date.new(2026, 10, 5), @admin.id ],
      [ paid.category_id, paid.payout_status, paid.paid_at, paid.paid_by_id ]
    pending = @company.expenses.find_by!(amount: 1)
    assert_equal PayoutSchedule.snapshot(Date.current, @company.payout_day), pending.planned_payout_date
    assert_equal "excel_import", AuditLog.find_by!(target_id: pending.id, action: "create").after["via"]
  end

  test "匯入收入：發票只填未稅、品項寫入、收款狀態" do
    row = { "單據編號" => "S1", "開立日" => "2026/10/1", "文件類型" => "發票", "客戶" => "王", "統一編號" => "04595257",
            "發票號碼" => "AB-12345678", "類別" => "銷售收入", "帳戶" => "主帳戶", "未稅金額" => 20, "收款狀態" => "已收款",
            "收款日" => "2026/10/2", "品名" => "A", "數量" => 2, "單價" => 10.5 }
    post_import(:income, [ row ])
    assert_response :created
    income = @company.incomes.sole
    assert_equal [ "invoice", 20, 1, 21, "collected", Date.new(2026, 10, 2) ],
      [ income.document_type, income.pre_tax_amt, income.tax_amt, income.amount, income.collection_status, income.collected_at ]
    assert_equal [ { "name" => "A", "quantity" => 2, "unit_price" => 10.5, "subtotal" => 21 } ], income.items
  end

  test "未填類別沒選對應 → 422；對應到已停用類別 → 409 請重新預覽" do
    rows = [ RECEIPT.merge("類別" => nil) ]
    post_import(:expense, rows)
    assert_response :unprocessable_content
    assert_equal "INVALID_CATEGORY_MAPPING", response.parsed_body["error"]

    stale = @company.categories.find_by!(kind: "expense", name: "伙食費")
    stale.update!(is_archived: true)
    post_import(:expense, rows, category_mapping: { "" => stale.id })
    assert_response :conflict
    assert_equal "CATEGORY_CHANGED", response.parsed_body["error"]
    assert_equal 0, @company.expenses.count
  end

  test "同名類別在垃圾桶：預覽標示 discarded，不可新增也不可重新啟用，只能對應既有類別" do
    trashed = @company.categories.find_by!(kind: "expense", name: "交際費")
    trashed.update!(is_archived: true)
    trashed.discard!
    rows = [ RECEIPT.merge("類別" => "交際費") ]

    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, rows))
    entry = response.parsed_body["categories"].sole
    assert_equal [ "discarded", false ], entry.values_at("state", "creatable")

    post_import(:expense, rows)
    assert_response :unprocessable_content
    assert_equal "INVALID_CATEGORY_MAPPING", response.parsed_body["error"]

    post_import(:expense, rows, category_mapping: { "交際費" => "reactivate" })
    assert_equal "INVALID_CATEGORY_MAPPING", response.parsed_body["error"]

    post_import(:expense, rows, category_mapping: { "交際費" => trashed.id })
    assert_response :conflict
    assert_equal "CATEGORY_CHANGED", response.parsed_body["error"]

    target = @company.categories.find_by!(kind: "expense", name: "伙食費")
    post_import(:expense, rows, category_mapping: { "交際費" => target.id })
    assert_response :created
    assert_equal target.id, @company.expenses.sole.category_id
    assert trashed.reload.is_archived
  end

  test "不可對應到別家公司的類別" do
    foreign = create_company(name: "別家公司").categories.find_by!(kind: "expense", name: "交通費")
    post_import(:expense, [ RECEIPT.merge("類別" => nil) ], category_mapping: { "" => foreign.id })
    assert_response :conflict
    assert_equal 0, @company.expenses.count
  end

  test "重新啟用只動本公司的停用類別，別家同名類別不受影響" do
    other_same = create_company(name: "別家公司").categories.find_by!(kind: "expense", name: "交際費")
    other_same.update!(is_archived: true)
    mine = @company.categories.find_by!(kind: "expense", name: "交際費")
    mine.update!(is_archived: true)

    post_import(:expense, [ RECEIPT.merge("類別" => "交際費") ], category_mapping: { "交際費" => "reactivate" })
    assert_response :created
    refute mine.reload.is_archived
    assert other_same.reload.is_archived
    assert_equal mine.id, @company.expenses.sole.category_id
  end

  test "類別名稱超過 50 字 → 不可新增，只能對應既有類別" do
    long_name = "類" * 51
    rows = [ RECEIPT.merge("類別" => long_name) ]
    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, rows))
    assert_equal [ "missing", false ], response.parsed_body["categories"].sole.values_at("state", "creatable")

    [ nil, { long_name => "create" } ].each do |mapping|
      post_import(:expense, rows, category_mapping: mapping)
      assert_response :unprocessable_content
      assert_equal "INVALID_CATEGORY_MAPPING", response.parsed_body["error"]
      assert_operator response.parsed_body["message"].length, :<, 60
    end

    travel = @company.categories.find_by!(kind: "expense", name: "交通費")
    post_import(:expense, rows, category_mapping: { long_name => travel.id })
    assert_response :created
    assert_equal travel.id, @company.expenses.sole.category_id
  end

  # ─── 預覽時移除 ─────────────────────────────

  test "只被移除或不匯入的單據用到的類別，不新增、也不要求對應" do
    rows = [
      RECEIPT.merge("單據編號" => "A", "含稅金額" => 1, "品名" => "x", "小計" => 1),
      RECEIPT.merge("類別" => "只給移除的用", "含稅金額" => 2),
      RECEIPT.merge("類別" => nil, "含稅金額" => 3),
      { "單據編號" => "A", "品名" => "y", "小計" => 1 },
      RECEIPT.merge("類別" => "只給不匯入的用", "日期" => nil),
      RECEIPT.merge("類別" => nil, "日期" => nil)
    ]
    post_preview(:expense, EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, rows))
    assert_equal [ "只給移除的用", "" ], response.parsed_body["categories"].map { |c| c["name"] }

    # 列號對不上可匯入單據的第一列（品項列、不匯入的列、不存在）→ 整次不匯入
    [ 5, 6, 99 ].each do |row|
      post_import(:expense, rows, excluded_rows: [ 3, row ])
      assert_response :unprocessable_content
      assert_equal [ "INVALID_EXCLUDED_ROWS", "檔案內容與預覽不同，請重新預覽" ],
        response.parsed_body.values_at("error", "message")
    end
    assert_equal 0, @company.expenses.count

    post_import(:expense, rows, excluded_rows: [ 3, 4 ])
    assert_response :created
    assert_equal [ 1, 2 ], response.parsed_body.values_at("created_count", "excluded_count")
    assert_empty response.parsed_body["created_categories"]
    assert_equal [ 1 ], @company.expenses.pluck(:amount)
    assert_nil @company.categories.find_by(name: "只給移除的用")
    assert_nil @company.categories.find_by(name: "只給不匯入的用")
  end

  test "全部移除 → 沒有可匯入的資料；非正整數或超過 1,000 個 → 422" do
    post_import(:expense, [ RECEIPT ], excluded_rows: [ 2 ])
    assert_response :unprocessable_content
    assert_equal "NOTHING_TO_IMPORT", response.parsed_body["error"]

    [ "[\"a\"]", "[0]", "[-2]", "[2.5]", (1..1001).to_a.to_json ].each do |excluded|
      post "/api/expenses/import", headers: auth_headers(@admin),
        params: { file: xlsx(EXPENSE_HEADERS, rows_for(EXPENSE_HEADERS, [ RECEIPT ])), excluded_rows: excluded }
      assert_response :unprocessable_content
      assert_equal "INVALID_EXCLUDED_ROWS", response.parsed_body["error"]
    end
  end

  # ─── 交易回滾 ─────────────────────────────

  test "任一筆寫入失敗整批回滾（含新增的類別）" do
    FailingSave.amount = 2
    post_import(:expense, [ RECEIPT.merge("類別" => "新類別", "含稅金額" => 1), RECEIPT.merge("含稅金額" => 2) ])
    assert_response :unprocessable_content
    assert_equal "IMPORT_FAILED", response.parsed_body["error"]
    assert_equal "第 3 列無法建立，整批未匯入，請檢查這列的資料", response.parsed_body["message"]
    assert_equal 0, @company.expenses.count
    assert_nil @company.categories.find_by(name: "新類別")
    assert_equal 0, AuditLog.where(company: @company).count
  ensure
    FailingSave.amount = nil
  end

  test "資料庫錯誤也整批回滾並回白話訊息，不回 500" do
    FailingSave.amount = 2
    FailingSave.error  = :db
    post_import(:expense, [ RECEIPT.merge("含稅金額" => 2) ])
    assert_response :unprocessable_content
    assert_equal "IMPORT_FAILED", response.parsed_body["error"]
    assert_equal 0, @company.expenses.count
  ensure
    FailingSave.amount = nil
    FailingSave.error  = nil
  end

  # ─── 權限 ─────────────────────────────

  test "員工不可下載範本、預覽、匯入" do
    employee = create_user(company: @company)
    get "/api/expenses/import/template", headers: auth_headers(employee)
    assert_response :forbidden
    post "/api/expenses/import/preview", headers: auth_headers(employee), params: { file: xlsx(EXPENSE_HEADERS, []) }
    assert_response :forbidden
    post "/api/incomes/import", headers: auth_headers(employee), params: { file: xlsx(INCOME_HEADERS, []) }
    assert_response :forbidden
  end

  private

  def opening_cash_of(account, year)
    get "/api/reports/cashflow", params: { from: "#{year}-01-01", to: "#{year}-12-31", account_id: account.id },
      headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body.dig("total", "opening_cash")
  end

  def create_expense_with(account)
    @company.expenses.create!(account: account, source: "general", created_by: @admin,
      category: @company.categories.find_by!(kind: "expense", name: "交通費"),
      document_type: "receipt", tax_rate: "exempt_0", amount: 9, date: Date.current)
  end

  def preview_one(row)
    preview_expense([ row ]).sole
  end

  def preview_expense(rows)
    preview(:expense, EXPENSE_HEADERS, rows).records
  end

  def preview(kind, headers, rows)
    ExcelImport::Parser.new(schema: ExcelImport::Schema.for(kind), user: @admin)
      .parse(xlsx(headers, rows_for(headers, rows)))
  end

  def amounts(record)
    record.attrs.values_at(:pre_tax_amt, :tax_amt, :amount)
  end

  def template_headers(kind)
    get "/api/#{kind}s/import/template", headers: auth_headers(@admin)
    assert_response :ok
    Roo::Excelx.new(write_tmp(response.body).path).sheet(0).row(1)
  end

  def post_preview(kind, headers, rows)
    post "/api/#{kind}s/import/preview", headers: auth_headers(@admin), params: { file: xlsx(headers, rows) }
  end

  def post_import(kind, rows, category_mapping: nil, account_mapping: nil, excluded_rows: nil)
    headers = kind == :expense ? EXPENSE_HEADERS : INCOME_HEADERS
    params = { file: xlsx(headers, rows_for(headers, rows)) }
    params[:category_mapping] = category_mapping.to_json if category_mapping
    params[:account_mapping]  = account_mapping.to_json if account_mapping
    params[:excluded_rows]    = excluded_rows.to_json if excluded_rows
    post "/api/#{kind}s/import", headers: auth_headers(@admin), params: params
  end

  def post_file(path)
    post "/api/expenses/import/preview", headers: auth_headers(@admin), params: { file: upload(path) }
  end

  # { 標題 => 值 } 轉成依標題順序的陣列
  def rows_for(headers, rows)
    rows.map { |row| headers.map { |h| row[h] } }
  end

  def xlsx(headers, rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "資料") do |sheet|
      sheet.add_row headers
      rows.each { |row| sheet.add_row row }
    end
    upload(write_tmp(package.to_stream.read).path)
  end

  def write_tmp(content)
    Tempfile.new([ "import", ".xlsx" ]).tap do |file|
      @tmpfiles << file
      file.binmode
      file.write(content)
      file.flush
    end
  end

  def upload(path)
    Rack::Test::UploadedFile.new(path, Mime[:xlsx].to_s, true, original_filename: "import.xlsx")
  end
end
