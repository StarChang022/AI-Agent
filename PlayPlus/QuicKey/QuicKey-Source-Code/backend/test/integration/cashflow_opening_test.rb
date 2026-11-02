require "test_helper"

# 期初的行為（PRD 規則 20、資料模型 §2.9）：期初、期末不存檔，由起始金額與收付款即時計算，
# 所以一律從現金流報表驗證使用者看到的數字：跨年帶入、舊年度異動後隔年數字正確、不多寫稽核。
class CashflowOpeningTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @income_category  = @company.categories.find_by!(kind: "income", name: "銷售收入")
    @expense_category = @company.categories.find_by!(kind: "expense", name: "交通費")
    @this_year = Date.current.year
    @last_year = @this_year - 1
  end

  test "起始月份當年期初是起始金額，之前的年度不顯示該帳戶" do
    account = old_account(amount: 1_000, year: @last_year)

    assert_nil opening(account, @last_year - 1)
    assert_nil closing(account, @last_year - 1)
    assert_equal 1_000.0, opening(account, @last_year)
    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "起始月份在年中：當年期初是起始金額，之前的月份為空" do
    account = old_account(amount: 1_000, year: @last_year, month: 7)

    rows = cashflow(account, @last_year)["rows"]
    assert_nil rows[5]["opening_cash"]
    assert_equal 1_000.0, rows[6]["opening_cash"]
    assert_equal 1_000.0, opening(account, @last_year)
  end

  test "跨年：年初期初等於上年期末，只算已收付、起始月份之後的紀錄" do
    account = old_account(amount: 1_000, year: @last_year - 1, month: 7)
    collected(account, 500, Date.new(@last_year - 1, 8, 1))
    paid(account, 200, Date.new(@last_year - 1, 12, 31))
    paid(account, 50, Date.new(@last_year, 1, 1))
    collected(account, 999, Date.new(@last_year - 1, 6, 30))                       # 早於起始月份
    @company.expenses.create!(expense_attrs(account, 777, Date.new(@last_year, 8, 1))) # 待付款

    assert_equal 1_000.0, opening(account, @last_year - 1)
    assert_equal 1_300.0, closing(account, @last_year - 1)
    assert_equal 1_300.0, opening(account, @last_year)
    assert_equal 1_250.0, closing(account, @last_year)
    assert_equal 1_250.0, opening(account, @this_year)
  end

  test "跨到新年度不需要任何動作，年初期初等於上年期末" do
    account = old_account(amount: 1_000, year: @this_year)
    paid(account, 300, Date.new(@this_year, 1, 2))

    travel_to Time.zone.local(@this_year + 1, 1, 1, 0, 10) do
      assert_equal 700.0, opening(account, @this_year + 1)
      assert_equal 700.0, closing(account, @this_year)
    end
  end

  test "期初可以是負數" do
    account = old_account(amount: 100, year: @last_year)
    paid(account, 500, Date.new(@last_year, 6, 1))

    assert_equal(-400.0, opening(account, @this_year))
  end

  test "今年度的紀錄不影響今年年初期初" do
    account = old_account(amount: 1_000, year: @last_year)
    paid(account, 300, Date.current)

    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "舊年度紀錄的金額、收付款日、付款狀態、帳戶異動後，隔年期初正確" do
    account = old_account(amount: 1_000, year: @last_year)
    other   = old_account(amount: 0, year: @last_year)
    expense = paid(account, 300, Date.new(@last_year, 6, 1))
    assert_equal 700.0, opening(account, @this_year)

    patch_expense(expense, amount: 100)
    assert_equal 900.0, opening(account, @this_year)

    patch_expense(expense, paid_at: Date.new(@this_year, 1, 2).iso8601)
    assert_equal 1_000.0, opening(account, @this_year), "付款日移到今年，不再影響今年年初"

    patch_expense(expense, paid_at: Date.new(@last_year, 1, 2).iso8601)
    assert_equal 900.0, opening(account, @this_year)

    patch "/api/expenses/#{expense.id}/revert-pay", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 1_000.0, opening(account, @this_year)

    patch "/api/expenses/#{expense.id}/pay", params: { paid_at: Date.new(@last_year, 3, 1).iso8601 },
      headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 900.0, opening(account, @this_year)

    patch_expense(expense, account_id: other.id)
    assert_equal 1_000.0, opening(account, @this_year)
    assert_equal(-100.0, opening(other, @this_year))
  end

  test "舊年度收入切換收款狀態、改帳戶後，隔年期初正確" do
    account = old_account(amount: 0, year: @last_year)
    other   = old_account(amount: 0, year: @last_year)
    income  = collected(account, 300, Date.new(@last_year, 6, 1))
    assert_equal 300.0, opening(account, @this_year)

    patch "/api/incomes/#{income.id}", params: { account_id: other.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 0.0, opening(account, @this_year)
    assert_equal 300.0, opening(other, @this_year)

    patch "/api/incomes/#{income.id}/revert-collect", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 0.0, opening(other, @this_year)
  end

  test "刪除、還原、永久刪除舊年度紀錄後，隔年期初正確" do
    account = old_account(amount: 1_000, year: @last_year)
    expense = paid(account, 300, Date.new(@last_year, 6, 1))
    assert_equal 700.0, opening(account, @this_year)

    expense.discard!
    assert_equal 1_000.0, opening(account, @this_year)
    expense.restore_from_trash!
    assert_equal 700.0, opening(account, @this_year)

    expense.destroy!
    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "作廢代墊款把舊年度已付款的連動支出移入垃圾桶後，隔年期初正確" do
    account  = old_account(amount: 1_000, year: @last_year)
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    expense.update!(payout_status: "paid", paid_at: Date.new(@last_year, 6, 1))
    assert_equal 900.0, opening(account, @this_year)

    patch "/api/reimbursements/#{r.id}/void", params: { comment: "測試" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "改起始金額後，起始月份當年與之後各年期初正確" do
    account = old_account(amount: 1_000, year: @last_year)
    paid(account, 300, Date.new(@last_year, 6, 1))

    patch_account(account, opening_amount: 2_000)
    assert_response :ok
    assert_equal 2_000.0, opening(account, @last_year)
    assert_equal 1_700.0, opening(account, @this_year)
  end

  test "起始月份往前調：更早的年度開始顯示，原本不計入的紀錄開始計入，起始金額不變" do
    account = old_account(amount: 1_000, year: @last_year)
    paid(account, 300, Date.new(@last_year - 1, 6, 1))
    assert_equal 1_000.0, opening(account, @this_year)

    patch_account(account, opening_month: "#{@last_year - 1}-01")
    assert_response :ok
    assert_equal 1_000.0, opening(account, @last_year - 1)
    assert_equal 700.0, opening(account, @last_year)
    assert_equal 700.0, opening(account, @this_year)
    assert_equal 1_000, account.reload.opening_amount
  end

  test "起始月份往後調跨年：之前的年度不顯示，之前的收付不計入，起始金額移到新的起始月份" do
    account = old_account(amount: 1_000, year: @last_year - 1)
    paid(account, 300, Date.new(@last_year - 1, 6, 1))
    assert_equal 700.0, opening(account, @this_year)

    patch_account(account, opening_month: "#{@last_year}-03")
    assert_response :ok
    assert_nil opening(account, @last_year - 1)
    assert_equal 1_000.0, opening(account, @last_year)
    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "同一年內往後調起始月份：之前的收付不計入" do
    account = old_account(amount: 1_000, year: @last_year, month: 1)
    paid(account, 300, Date.new(@last_year, 2, 1))
    assert_equal 700.0, opening(account, @this_year)

    patch_account(account, opening_month: "#{@last_year}-03")
    assert_response :ok
    assert_equal 1_000.0, opening(account, @this_year)
  end

  test "所有帳戶：起始月份落在不同季時，每季期初、期末正確" do
    feb = old_account(amount: 1_000, year: @last_year, month: 2)
    may = old_account(amount: 200, year: @last_year, month: 5)
    nov = old_account(amount: 30, year: @last_year, month: 11)
    paid(feb, 100, Date.new(@last_year, 3, 1))
    collected(may, 50, Date.new(@last_year, 6, 1))
    collected(may, 999, Date.new(@last_year, 2, 1)) # 早於該帳戶起始月份，不計入
    paid(nov, 5, Date.new(@last_year, 12, 1))

    body = quarterly(@last_year)
    assert_equal [ 1_000.0, 1_100.0, 1_150.0, 1_180.0 ], body["rows"].map { |r| r["opening_cash"] }
    assert_equal [ 900.0, 1_150.0, 1_150.0, 1_175.0 ], body["rows"].map { |r| r["closing_cash"] }
    assert_equal [ -100.0, 50.0, 0.0, -5.0 ], body["rows"].map { |r| r["net"] }
    assert_equal 1_000.0, body.dig("total", "opening_cash")
    assert_equal 1_175.0, body.dig("total", "closing_cash")

    assert_equal 1_175.0, quarterly(@this_year)["rows"].first["opening_cash"]
  end

  test "這些變動不多寫稽核，只有原異動的稽核" do
    account = old_account(amount: 1_000, year: @last_year)
    expense = paid(account, 300, Date.new(@last_year, 6, 1))

    patch_expense(expense, amount: 100)
    assert_equal 1, AuditLog.where(target_type: "expense", target_id: expense.id, action: "update").count
    assert_empty AuditLog.where(target_type: "account")

    expense.discard!
    assert_empty AuditLog.where(target_type: "account")

    patch_account(account, opening_amount: 2_000)
    patch_account(account, opening_month: "#{@last_year}-02")
    assert_equal 2, AuditLog.where(target_type: "account", target_id: account.id).count
    assert_equal 2, AuditLog.where(company: @company).where.not(target_type: "expense").count
  end

  test "帳戶進垃圾桶不計入合計，還原後期初正確" do
    kept    = old_account(amount: 100, year: @last_year)
    account = old_account(amount: 1_000, year: @last_year)
    assert_equal 1_100.0, all_accounts_opening(@this_year)

    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal 100.0, all_accounts_opening(@this_year)
    assert_equal 100.0, opening(kept, @this_year)

    patch "/api/accounts/#{account.id}/restore", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal 1_000.0, opening(account, @this_year)
    assert_equal 1_100.0, all_accounts_opening(@this_year)
  end

  test "別家公司的紀錄不影響這家的期初" do
    account = old_account(amount: 1_000, year: @last_year)
    other_company = create_company(name: "別家")
    other_admin   = create_user(company: other_company, role: "admin")
    other_account = create_account(company: other_company, opening_month: Date.new(@last_year, 1, 1))
    other_company.expenses.create!(account: other_account, source: "general", created_by: other_admin,
      category: other_company.categories.find_by!(kind: "expense", name: "交通費"),
      document_type: "receipt", tax_rate: "exempt_0", amount: 300, date: Date.current,
      payout_status: "paid", paid_at: Date.new(@last_year, 6, 1))

    assert_equal 1_000.0, opening(account, @this_year)
    assert_equal 1_000.0, all_accounts_opening(@this_year)
  end

  private

  def old_account(amount:, year:, month: 1)
    create_account(company: @company, opening_amount: amount, opening_month: Date.new(year, month, 1))
  end

  def cashflow(account, year)
    query = { from: "#{year}-01-01", to: "#{year}-12-31" }
    query[:account_id] = account.id if account
    get "/api/reports/cashflow", params: query, headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body
  end

  def quarterly(year)
    get "/api/reports/cashflow", params: { from: "#{year}-01-01", to: "#{year}-12-31", bucket: "quarter" },
      headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body
  end

  def opening(account, year)
    cashflow(account, year).dig("total", "opening_cash")
  end

  def closing(account, year)
    cashflow(account, year).dig("total", "closing_cash")
  end

  def all_accounts_opening(year)
    opening(nil, year)
  end

  def expense_attrs(account, amount, date)
    { account: account, source: "general", created_by: @admin, category: @expense_category,
      document_type: "receipt", tax_rate: "exempt_0", amount: amount, date: date }
  end

  def paid(account, amount, date)
    @company.expenses.create!(expense_attrs(account, amount, date).merge(payout_status: "paid", paid_at: date))
  end

  def collected(account, amount, date)
    @company.incomes.create!(account: account, created_by: @admin, customer: "王", category: @income_category,
      document_type: "receipt", tax_rate: "exempt_0", amount: amount, date: date,
      collection_status: "collected", collected_at: date)
  end

  def patch_expense(expense, **body)
    patch "/api/expenses/#{expense.id}", params: body, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  def patch_account(account, **body)
    patch "/api/accounts/#{account.id}", params: body, headers: auth_headers(@admin), as: :json
  end
end
