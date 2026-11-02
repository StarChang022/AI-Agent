require "test_helper"

# 帳戶設定（PRD 規則 18、20、21）：新增編輯的驗證與稽核、刪除檢查、垃圾桶、公司隔離、角色權限。
class AccountsTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "新增帳戶：寫入起始金額，起始月份為當月，寫稽核" do
    post_account(name: " 永豐-總公司 ", account_type: "bank", opening_amount: "100000.5")
    assert_response :created

    body = response.parsed_body
    assert_equal "永豐-總公司", body["name"]
    assert_equal 100000.5, body["opening_amount"]
    assert_equal "TWD", body["currency"]
    assert_equal Date.current.beginning_of_month.iso8601, body["opening_month"]

    account = Account.find(body["id"])
    assert_equal BigDecimal("100000.5"), account.opening_amount

    log = audit_logs(account).sole
    assert_equal "create", log.action
    assert_equal "永豐-總公司", log.after["name"]
    assert_equal 100000.5, log.after["opening_amount"]
  end

  test "起始月份可選過去月份，收 YYYY-MM 或日期，一律轉成該月第一天" do
    post_account(name: "甲", account_type: "bank", opening_amount: 100, opening_month: "2024-03")
    assert_response :created
    assert_equal "2024-03-01", response.parsed_body["opening_month"]
    assert_equal Date.new(2024, 3, 1), Account.find(response.parsed_body["id"]).opening_month

    post_account(name: "乙", account_type: "bank", opening_amount: 100, opening_month: "2024-03-15")
    assert_response :created
    assert_equal "2024-03-01", response.parsed_body["opening_month"]
  end

  test "起始月份範圍 2000 年 1 月至當月，建立和修改都驗證" do
    this_month = Date.current.beginning_of_month
    post_account(name: "下限", account_type: "bank", opening_amount: 0, opening_month: "2000-01")
    assert_response :created
    post_account(name: "當月", account_type: "bank", opening_amount: 0, opening_month: this_month.strftime("%Y-%m"))
    assert_response :created

    invalid = [ "", nil, "1999-12", this_month.next_month.strftime("%Y-%m"), "2026-13", "2026", "abc", [ "2026-01" ] ]
    invalid.each do |month|
      post_account(name: "壞月份", account_type: "bank", opening_amount: 0, opening_month: month)
      assert_response :unprocessable_content, month.inspect
      assert_equal "INVALID_OPENING_MONTH", response.parsed_body["error"]
    end

    account = create_account(company: @company, name: "主帳戶")
    invalid.each do |month|
      patch_account(account, opening_month: month)
      assert_response :unprocessable_content, month.inspect
      assert_equal "INVALID_OPENING_MONTH", response.parsed_body["error"]
    end
    assert_equal this_month, account.reload.opening_month
  end

  test "模型層也擋超出範圍的起始月份；舊帳戶改其他欄位不受影響" do
    account = create_account(company: @company, opening_month: Date.current.beginning_of_month)
    account.opening_month = Date.current.next_month.beginning_of_month
    assert_not account.valid?
    assert account.errors.key?(:opening_month)

    travel_to 2.months.from_now do
      account.reload.update!(name: "改名")
    end
  end

  test "修改起始月份寫稽核含前後值，起始金額不變；沒變不寫" do
    account = create_account(company: @company, opening_amount: 100, opening_month: Date.new(2026, 3, 1))

    patch_account(account, opening_month: "2026-03")
    assert_response :ok
    assert_empty audit_logs(account)

    patch_account(account, opening_month: "2026-01")
    assert_response :ok
    assert_equal "2026-01-01", response.parsed_body["opening_month"]
    assert_equal 100.0, response.parsed_body["opening_amount"]
    log = audit_logs(account).sole
    assert_equal({ "opening_month" => "2026-03-01" }, log.before)
    assert_equal({ "opening_month" => "2026-01-01" }, log.after)
  end

  test "下拉回傳起始月份" do
    create_account(company: @company, name: "主帳戶", opening_month: Date.new(2026, 3, 1))
    get "/api/accounts/options", headers: auth_headers(@admin)
    assert_equal "2026-03-01", response.parsed_body["data"].sole["opening_month"]
  end

  test "impact：只算已收付、不含垃圾桶，分支出收入回傳；不寫入" do
    account = create_account(company: @company, opening_amount: 100, opening_month: Date.new(2026, 1, 1))
    other   = create_account(company: @company, name: "別帳戶", opening_month: Date.new(2026, 1, 1))
    settled_expense(account, Date.new(2026, 2, 1))
    settled_expense(account, Date.new(2026, 7, 31))
    settled_expense(account, Date.new(2026, 8, 1))              # 當月不算
    settled_expense(account, Date.new(2026, 2, 1)).discard!     # 垃圾桶不算
    settled_expense(other, Date.new(2026, 2, 1))                # 別帳戶不算
    create_expense(account)                                     # 待付款不算
    create_income(account)                                      # 待收款不算
    create_income(account).update!(collection_status: "collected", collected_at: Date.new(2026, 3, 1))

    get "/api/accounts/#{account.id}/opening-month-impact", params: { opening_month: "2026-08" }, headers: auth_headers(@admin)
    assert_response :ok
    assert_equal({
      "opening_month" => "2026-08-01",
      "outside_cash_flow_count" => 3,
      "outside_cash_flow" => { "expenses" => 2, "incomes" => 1 },
      "blocking_transfer_count" => 0,
      "earliest_transfer_date" => nil
    }, response.parsed_body)
    assert_equal Date.new(2026, 1, 1), account.reload.opening_month
    assert_empty audit_logs(account)
  end

  test "impact：月份不合法 → 422；別家帳戶 → 404；員工 → 403" do
    account = create_account(company: @company)
    get "/api/accounts/#{account.id}/opening-month-impact", params: { opening_month: "abc" }, headers: auth_headers(@admin)
    assert_response :unprocessable_content
    assert_equal "INVALID_OPENING_MONTH", response.parsed_body["error"]

    other_admin = create_user(company: create_company(name: "別家"), role: "admin")
    get "/api/accounts/#{account.id}/opening-month-impact", params: { opening_month: "2026-01" }, headers: auth_headers(other_admin)
    assert_response :not_found

    employee = create_user(company: @company)
    get "/api/accounts/#{account.id}/opening-month-impact", params: { opening_month: "2026-01" }, headers: auth_headers(employee)
    assert_response :forbidden
  end

  test "起始月份往後調超過已有收付款仍可儲存，損益不變" do
    account = create_account(company: @company, opening_month: Date.new(2026, 1, 1))
    settled_expense(account, Date.new(2026, 2, 1))

    patch_account(account, opening_month: "2026-08")
    assert_response :ok

    get "/api/reports/profit-loss", params: { from: "2026-01-01", to: "2026-12-31" }, headers: auth_headers(@admin)
    assert_equal 100.0, response.parsed_body.dig("total", "expense")
    get "/api/reports/cashflow", params: { from: "2026-01-01", to: "2026-12-31" }, headers: auth_headers(@admin)
    assert_equal 0.0, response.parsed_body.dig("total", "cash_out")
  end

  test "收付款日早於起始月份可以儲存，不計入現金流，損益照常" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 8, 1))
    post "/api/expenses", headers: auth_headers(@admin), as: :json, params: {
      category_id: @company.categories.find_by!(kind: "expense", name: "交通費").id, account_id: account.id,
      amount: 100, date: "2026-05-01", document_type: "receipt", tax_rate: "exempt_0",
      payout_status: "paid", paid_at: "2026-05-01"
    }
    assert_response :created

    get "/api/reports/cashflow", params: { from: "2026-01-01", to: "2026-12-31" }, headers: auth_headers(@admin)
    assert_equal 0.0, response.parsed_body.dig("total", "cash_out")
    assert_equal 1_000.0, response.parsed_body.dig("total", "closing_cash")
    get "/api/reports/profit-loss", params: { from: "2026-01-01", to: "2026-12-31" }, headers: auth_headers(@admin)
    assert_equal 100.0, response.parsed_body.dig("total", "expense")
  end

  test "預設帳戶未被引用時可刪除；有引用時和一般帳戶一樣不可刪" do
    account = Account.create_default!(@company)
    create_expense(account)
    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :conflict

    account.expenses.destroy_all
    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_not_nil account.reload.deleted_at
  end

  test "模型層也擋負數與超過上限的起始金額；上限本身可以" do
    account = create_account(company: @company)
    [ -0.01, Account::MAX_AMOUNT + 0.01 ].each do |amount|
      account.opening_amount = amount
      assert_not account.valid?, amount.to_s
      assert account.errors.key?(:opening_amount)
    end

    account.opening_amount = Account::MAX_AMOUNT
    assert account.valid?
  end

  test "起始金額可為 0；空白、負數、非數字、超過上限都擋" do
    post_account(name: "零元", account_type: "cash", opening_amount: 0)
    assert_response :created

    [ nil, "", -1, "abc", "10000000000" ].each do |amount|
      post_account(name: "壞金額", account_type: "cash", opening_amount: amount)
      assert_response :unprocessable_content
      assert_equal "INVALID_OPENING_AMOUNT", response.parsed_body["error"]
    end
  end

  test "名稱空白、過長、類型不對都擋" do
    post_account(name: "  ", account_type: "cash", opening_amount: 0)
    assert_equal "INVALID_NAME", response.parsed_body["error"]

    post_account(name: "長" * 51, account_type: "cash", opening_amount: 0)
    assert_equal "INVALID_NAME", response.parsed_body["error"]

    post_account(name: "甲", account_type: "credit", opening_amount: 0)
    assert_equal "INVALID_ACCOUNT_TYPE", response.parsed_body["error"]
  end

  test "名稱重複不分大小寫、忽略前後空格；別家公司同名不受影響" do
    create_account(company: @company, name: "Cash")

    post_account(name: " cash ", account_type: "cash", opening_amount: 0)
    assert_response :conflict
    assert_equal "DUPLICATE_NAME", response.parsed_body["error"]
    assert_equal "已有同名帳戶，請換一個名稱", response.parsed_body["message"]

    other = create_company(name: "別家")
    create_account(company: other, name: "別家帳戶")
    post_account(name: "別家帳戶", account_type: "cash", opening_amount: 0)
    assert_response :created
  end

  test "垃圾桶內的同名帳戶也算重複，還原不會撞名" do
    account = create_account(company: @company, name: "零用金")
    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :ok

    post_account(name: "零用金", account_type: "cash", opening_amount: 0)
    assert_response :conflict
    assert_equal "垃圾桶內已有同名帳戶，請還原或永久刪除後再試", response.parsed_body["message"]
    assert_equal account.id, response.parsed_body.dig("account", "id")
    assert_not_nil response.parsed_body.dig("account", "deleted_at")

    patch "/api/accounts/#{account.id}/restore", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil account.reload.deleted_at
  end

  test "修改起始金額寫稽核含前後值，類型不可改" do
    account = create_account(company: @company, name: "主帳戶", opening_amount: 100)

    patch_account(account, opening_amount: 120, account_type: "cash")
    assert_response :ok
    assert_equal 120.0, response.parsed_body["opening_amount"]
    assert_equal "bank", response.parsed_body["account_type"]

    account.reload
    assert_equal 120, account.opening_amount

    log = audit_logs(account).sole
    assert_equal "update", log.action
    assert_equal({ "opening_amount" => 100.0 }, log.before)
    assert_equal({ "opening_amount" => 120.0 }, log.after)
  end

  test "改名稱寫稽核；沒有變更不寫稽核，也不會誤判重複" do
    account = create_account(company: @company, name: "主帳戶", opening_amount: 100)

    patch_account(account, name: "主帳戶", opening_amount: 100)
    assert_response :ok
    assert_empty audit_logs(account)

    patch_account(account, name: "新名稱")
    assert_response :ok
    assert_equal({ "name" => "主帳戶" }, audit_logs(account).sole.before)
    assert_equal({ "name" => "新名稱" }, audit_logs(account).sole.after)
  end

  test "改成與其他帳戶相同名稱 → 409" do
    create_account(company: @company, name: "甲")
    account = create_account(company: @company, name: "乙")

    patch_account(account, name: "甲")
    assert_response :conflict
    assert_equal "DUPLICATE_NAME", response.parsed_body["error"]
    assert_equal "乙", account.reload.name
  end

  test "被收支引用不可刪除，垃圾桶內的紀錄也算" do
    account = create_account(company: @company, name: "主帳戶")
    expense = create_expense(account)
    create_income(account)

    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "ACCOUNT_IN_USE", response.parsed_body["error"]
    assert_equal "此帳戶已有 1 筆支出、1 筆收入使用（含垃圾桶內的紀錄），不能刪除", response.parsed_body["message"]
    assert_equal({ "expenses" => 1, "incomes" => 1, "recurring_templates" => 0, "transfers" => 0 }, response.parsed_body["references"])
    assert_nil account.reload.deleted_at

    account.incomes.destroy_all
    expense.discard!
    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal({ "expenses" => 1, "incomes" => 0, "recurring_templates" => 0, "transfers" => 0 }, response.parsed_body["references"])
  end

  test "列表帶引用筆數與是否可刪除" do
    used   = create_account(company: @company, name: "用過")
    unused = create_account(company: @company, name: "沒用過")
    create_expense(used)

    get "/api/accounts", headers: auth_headers(@admin)
    assert_response :ok
    rows = response.parsed_body["data"].index_by { |r| r["id"] }
    assert_equal({ "expenses" => 1, "incomes" => 0, "recurring_templates" => 0, "transfers" => 0 }, rows[used.id]["references"])
    assert_equal false, rows[used.id]["deletable"]
    assert_equal true, rows[unused.id]["deletable"]
    assert_equal({ "total" => 2, "page" => 1, "page_size" => 10 }, response.parsed_body["meta"])
  end

  test "刪除進垃圾桶：列表與下拉消失，垃圾桶看得到時間與操作人，寫稽核" do
    account = create_account(company: @company, name: "主帳戶")

    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal "delete", audit_logs(account).sole.action

    get "/api/accounts", headers: auth_headers(@admin)
    assert_empty response.parsed_body["data"]
    get "/api/accounts/options", headers: auth_headers(@admin)
    assert_empty response.parsed_body["data"]

    get "/api/accounts", params: { discarded: true }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].sole
    assert_equal account.id, row["id"]
    assert_not_nil row["deleted_at"]
    assert_equal @admin.name, row.dig("deleted_by", "name")
  end

  test "垃圾桶內不可編輯；未進垃圾桶不可還原或永久刪除" do
    account = create_account(company: @company)
    patch "/api/accounts/#{account.id}/restore", headers: auth_headers(@admin)
    assert_response :not_found
    delete "/api/accounts/#{account.id}/purge", headers: auth_headers(@admin)
    assert_response :not_found

    account.discard!
    patch_account(account, name: "改名")
    assert_response :not_found
  end

  test "永久刪除：帳戶移除，稽核保存完整內容" do
    account = create_account(company: @company, name: "主帳戶", opening_amount: 500)
    account.discard!

    delete "/api/accounts/#{account.id}/purge", headers: auth_headers(@admin)
    assert_response :ok
    assert_not Account.exists?(account.id)

    log = audit_logs(account).sole
    assert_equal "purge", log.action
    assert_equal "主帳戶", log.before["name"]
    assert_equal "bank", log.before["account_type"]
    assert_equal 500.0, log.before["opening_amount"]
  end

  test "別家公司的帳戶看不到也動不了" do
    other_admin = create_user(company: create_company(name: "別家"), role: "admin")
    account = create_account(company: @company, name: "主帳戶")

    get "/api/accounts", headers: auth_headers(other_admin)
    assert_empty response.parsed_body["data"]
    get "/api/accounts/options", headers: auth_headers(other_admin)
    assert_empty response.parsed_body["data"]

    patch "/api/accounts/#{account.id}", params: { name: "駭" }, headers: auth_headers(other_admin), as: :json
    assert_response :not_found
    delete "/api/accounts/#{account.id}", headers: auth_headers(other_admin)
    assert_response :not_found

    account.discard!
    patch "/api/accounts/#{account.id}/restore", headers: auth_headers(other_admin)
    assert_response :not_found
    delete "/api/accounts/#{account.id}/purge", headers: auth_headers(other_admin)
    assert_response :not_found
    assert Account.exists?(account.id)
  end

  test "員工不能使用帳戶 API" do
    employee = create_user(company: @company)
    account  = create_account(company: @company)
    headers  = auth_headers(employee)

    get "/api/accounts", headers: headers
    assert_response :forbidden
    get "/api/accounts/options", headers: headers
    assert_response :forbidden
    post "/api/accounts", params: { name: "甲" }, headers: headers, as: :json
    assert_response :forbidden
    patch "/api/accounts/#{account.id}", params: { name: "甲" }, headers: headers, as: :json
    assert_response :forbidden
    delete "/api/accounts/#{account.id}", headers: headers
    assert_response :forbidden
  end

  private

  def post_account(**body)
    post "/api/accounts", params: body, headers: auth_headers(@admin), as: :json
  end

  def patch_account(account, **body)
    patch "/api/accounts/#{account.id}", params: body, headers: auth_headers(@admin), as: :json
  end

  def audit_logs(account)
    AuditLog.where(target_type: "account", target_id: account.id).order(:created_at).to_a
  end

  def settled_expense(account, paid_at)
    create_expense(account).tap { |e| e.update!(payout_status: "paid", paid_at: paid_at) }
  end

  def create_expense(account)
    @company.expenses.create!(account: account, source: "general", created_by: @admin,
      category: @company.categories.find_by!(kind: "expense", name: "交通費"),
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
  end

  def create_income(account)
    @company.incomes.create!(account: account, created_by: @admin, customer: "王",
      category: @company.categories.find_by!(kind: "income", name: "銷售收入"),
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
  end
end
