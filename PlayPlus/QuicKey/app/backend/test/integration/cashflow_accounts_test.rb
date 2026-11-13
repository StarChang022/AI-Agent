require "test_helper"

# 現金流報表的帳戶（PRD 規則 20）：期初、期末的金額計算、建立月之前不計入、單一帳戶、公司隔離。
class CashflowAccountsTest < ActionDispatch::IntegrationTest
  YEAR = { from: "2026-01-01", to: "2026-12-31" }.freeze

  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @income_category  = @company.categories.find_by!(kind: "income", name: "銷售收入")
    @expense_category = @company.categories.find_by!(kind: "expense", name: "交通費")
  end

  test "8 月建立的帳戶：8 月期初等於起始金額，之後期初等於上月期末，1～7 月為空" do
    account = create_account(company: @company, opening_amount: 50_000, opening_month: Date.new(2026, 8, 1))
    collected(account, 1_000, Date.new(2026, 8, 10))
    paid(account, 300, Date.new(2026, 8, 20))
    paid(account, 200, Date.new(2026, 10, 1))

    body = cashflow
    aug, sep, oct = body["rows"].values_at(7, 8, 9)

    body["rows"].first(7).each do |row|
      assert_nil row["opening_cash"]
      assert_nil row["closing_cash"]
    end
    assert_equal 50_000.0, aug["opening_cash"]
    assert_equal 700.0, aug["net"]
    assert_equal 50_700.0, aug["closing_cash"]
    assert_equal 50_700.0, sep["opening_cash"]
    assert_equal 50_700.0, sep["closing_cash"]
    assert_equal 50_700.0, oct["opening_cash"]
    assert_equal 50_500.0, oct["closing_cash"]

    assert_equal 50_000.0, body.dig("total", "opening_cash")
    assert_equal 50_500.0, body.dig("total", "closing_cash")
  end

  test "跨年：年初期初等於上年期末" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2025, 11, 1))
    collected(account, 500, Date.new(2025, 12, 5))

    assert_equal 1_500.0, cashflow["rows"].first["opening_cash"]
    assert_equal 1_500.0, cashflow(from: "2026-01-01", to: "2026-03-31", bucket: "quarter").dig("total", "opening_cash")
  end

  test "季、年彙總：期初是期間第一天，帳戶在期間中建立時併入起始金額" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 2, 1))
    paid(account, 100, Date.new(2026, 5, 1))

    q1, q2 = cashflow(bucket: "quarter")["rows"].first(2)
    assert_equal 1_000.0, q1["opening_cash"]
    assert_equal 1_000.0, q1["closing_cash"]
    assert_equal 1_000.0, q2["opening_cash"]
    assert_equal 900.0, q2["closing_cash"]

    year = cashflow(bucket: "year")["rows"].sole
    assert_equal 1_000.0, year["opening_cash"]
    assert_equal 900.0, year["closing_cash"]
  end

  test "自訂區間從月中開始：期初算到區間開始前一天" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 1, 1))
    paid(account, 100, Date.new(2026, 3, 5))
    paid(account, 50, Date.new(2026, 3, 20))

    row = cashflow(from: "2026-03-15", to: "2026-03-31")["rows"].sole
    assert_equal 900.0, row["opening_cash"]
    assert_equal(-50.0, row["net"])
    assert_equal 850.0, row["closing_cash"]
  end

  test "建立月之前的收付款不計入該帳戶" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 8, 1))
    collected(account, 500, Date.new(2026, 5, 1))
    paid(account, 300, Date.new(2026, 7, 31))

    body = cashflow
    assert_equal 0.0, body["rows"][4]["cash_in"]
    assert_equal 0.0, body["rows"][6]["cash_out"]
    assert_equal 1_000.0, body["rows"][7]["opening_cash"]
    assert_equal 0.0, body.dig("total", "net")
  end

  test "所有帳戶合計與切換單一帳戶；待收待付清單跟著篩" do
    bank  = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 1, 1))
    petty = create_account(company: @company, opening_amount: 100, opening_month: Date.new(2026, 3, 1))
    collected(bank, 200, Date.new(2026, 1, 10))
    paid(petty, 30, Date.new(2026, 3, 10))
    uncollected(bank)
    pending(petty)

    all = cashflow
    assert_equal 1_000.0, all["rows"][0]["opening_cash"]
    assert_equal 1_200.0, all["rows"][1]["closing_cash"]
    assert_equal 1_300.0, all["rows"][2]["opening_cash"], "新帳戶的起始金額併入當月期初"
    assert_equal 1_270.0, all["rows"][2]["closing_cash"]
    assert_equal 1, all["pending_in"].size
    assert_equal 1, all["pending_out"].size

    one = cashflow(account_id: petty.id)
    assert_nil one["rows"][1]["closing_cash"]
    assert_equal 100.0, one["rows"][2]["opening_cash"]
    assert_equal 70.0, one["rows"][2]["closing_cash"]
    assert_equal 0.0, one.dig("total", "cash_in")
    assert_equal 30.0, one.dig("total", "cash_out")
    assert_empty one["pending_in"]
    assert_equal 1, one["pending_out"].size
  end

  test "待收款、待付款、垃圾桶內的紀錄不計入餘額；改起始金額反映到各期" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 1, 1))
    uncollected(account)
    pending(account)
    paid(account, 400, Date.new(2026, 2, 1)).discard!

    assert_equal 1_000.0, cashflow.dig("total", "closing_cash")

    patch "/api/accounts/#{account.id}", params: { opening_amount: 2_000 }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 2_000.0, cashflow.dig("total", "closing_cash")
  end

  test "沒有帳戶時期初期末為空" do
    body = cashflow
    assert_nil body["rows"].first["opening_cash"]
    assert_nil body.dig("total", "opening_cash")
    assert_nil body.dig("total", "closing_cash")
  end

  test "別家公司或垃圾桶內的帳戶 → 422；別家的金額不計入" do
    other   = create_company(name: "別家")
    foreign = create_account(company: other, opening_amount: 9_999, opening_month: Date.new(2026, 1, 1))
    trashed = create_account(company: @company, name: "已刪除", opening_amount: 5, opening_month: Date.new(2026, 1, 1))
    trashed.discard!
    account = create_account(company: @company, opening_amount: 1, opening_month: Date.new(2026, 1, 1))

    [ foreign, trashed ].each do |target|
      get "/api/reports/cashflow", params: YEAR.merge(account_id: target.id), headers: auth_headers(@admin)
      assert_response :unprocessable_content
      assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    end

    assert_equal 1.0, cashflow.dig("total", "closing_cash")
    assert_equal 1.0, cashflow(account_id: account.id).dig("total", "closing_cash")
  end

  test "xlsx 吃同一組參數" do
    account = create_account(company: @company, opening_amount: 1_000, opening_month: Date.new(2026, 1, 1))
    get "/api/reports/cashflow.xlsx", params: YEAR.merge(account_id: account.id), headers: auth_headers(@admin)
    assert_response :ok
    assert_equal Mime[:xlsx].to_s, response.media_type
  end

  private

  def cashflow(**query)
    get "/api/reports/cashflow", params: YEAR.merge(query), headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body
  end

  def income_attrs(account, amount, date)
    { account: account, created_by: @admin, customer: "王", category: @income_category,
      document_type: "receipt", tax_rate: "exempt_0", amount: amount, date: date }
  end

  def expense_attrs(account, amount, date)
    { account: account, source: "general", created_by: @admin, category: @expense_category,
      document_type: "receipt", tax_rate: "exempt_0", amount: amount, date: date }
  end

  def collected(account, amount, date)
    @company.incomes.create!(income_attrs(account, amount, date).merge(collection_status: "collected", collected_at: date))
  end

  def uncollected(account)
    @company.incomes.create!(income_attrs(account, 7, Date.new(2026, 1, 1)))
  end

  def paid(account, amount, date)
    @company.expenses.create!(expense_attrs(account, amount, date).merge(payout_status: "paid", paid_at: date))
  end

  def pending(account)
    @company.expenses.create!(expense_attrs(account, 7, Date.new(2026, 1, 1)))
  end
end
