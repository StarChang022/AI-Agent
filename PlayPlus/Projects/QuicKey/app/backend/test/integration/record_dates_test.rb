require "test_helper"
require Rails.root.join("db/migrate/20261105000002_add_invoice_date_to_reimbursements")

# 收支日期欄位（PRD 第 10、23 條；docs/資料模型.md §2.2、§2.6、§3.1）：應付日期預設、
# 跟著發生日期、手動與改回自動排程、應收日期、狀態切換、發票日期（含代墊款請款）、待收付分組、既有資料補值後的規則。
class RecordDatesTest < ActionDispatch::IntegrationTest
  TODAY = Date.new(2026, 11, 10)

  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @company.update!(payout_day: 25)
    @admin   = create_user(company: @company, role: "admin")
    @account = account_for(@company)
    @expense_category = @company.categories.of_kind("expense").active.first
    @income_category  = @company.categories.of_kind("income").active.first
  end

  # ─── 應付日期預設 ─────────────────────────────

  test "付款日計算：當天就是付款日用當天，已過當月付款日推到下個月" do
    assert_equal Date.new(2026, 11, 25), PayoutSchedule.snapshot(Date.new(2026, 11, 5), 25)
    assert_equal Date.new(2026, 11, 25), PayoutSchedule.snapshot(Date.new(2026, 11, 25), 25)
    assert_equal Date.new(2026, 12, 25), PayoutSchedule.snapshot(Date.new(2026, 11, 26), 25)
  end

  test "付款日計算：31 號遇到短月退到月底，12 月過了跨到隔年" do
    assert_equal Date.new(2026, 2, 28), PayoutSchedule.snapshot(Date.new(2026, 2, 28), 31)
    assert_equal Date.new(2028, 2, 29), PayoutSchedule.snapshot(Date.new(2028, 2, 1), 31)
    assert_equal Date.new(2026, 4, 30), PayoutSchedule.snapshot(Date.new(2026, 4, 1), 31)
    assert_equal Date.new(2026, 2, 28), PayoutSchedule.snapshot(Date.new(2026, 1, 31), 30)
    assert_equal Date.new(2027, 1, 30), PayoutSchedule.snapshot(Date.new(2026, 12, 31), 30)
    assert_equal Date.new(2027, 1, 25), PayoutSchedule.snapshot(Date.new(2026, 12, 26), 25)
    assert_nil PayoutSchedule.snapshot(Date.new(2026, 11, 5), nil)
  end

  test "新增支出：以登錄當天往後找付款日，不看發生日期；已付款也有應付日期" do
    pending = create_expense!(date: "2026-10-01")
    paid    = create_expense!(date: "2026-10-01", payout_status: "paid", paid_at: "2026-10-02")

    [ pending, paid ].each do |body|
      assert_equal [ "2026-11-25", "2026-11-25", false ],
        body.values_at("planned_payout_date", "auto_planned_payout_date", "planned_payout_manual")
    end
  end

  test "新增支出：登錄當天剛好是付款日時用當天" do
    @company.update!(payout_day: 10)
    body = create_expense!(date: "2026-11-01")
    assert_equal "2026-11-10", body["planned_payout_date"]
  end

  test "新增支出：公司關閉付款日時，應付日期為發生日期、自動值為 null" do
    @company.update!(payout_day: nil)
    body = create_expense!(date: "2026-11-03")
    assert_equal [ "2026-11-03", nil, false ],
      body.values_at("planned_payout_date", "auto_planned_payout_date", "planned_payout_manual")
  end

  test "代墊款核准：從核准當天往後找付款日，不看消費日" do
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)
    r.update!(incurred_at: Date.new(2026, 9, 1))
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    expense = @company.expenses.find_by!(source_ref_id: r.id)
    assert_equal [ Date.new(2026, 9, 1), Date.new(2026, 11, 25), Date.new(2026, 11, 25) ],
      [ expense.date, expense.planned_payout_date, expense.auto_planned_payout_date ]
  end

  test "代墊款核准：公司關閉付款日時應付日期為消費日" do
    @company.update!(payout_day: nil)
    r = create_reimbursement(employee: create_user(company: @company))
    r.update!(incurred_at: Date.new(2026, 9, 1))
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    expense = @company.expenses.find_by!(source_ref_id: r.id)
    assert_equal [ Date.new(2026, 9, 1), nil ], [ expense.planned_payout_date, expense.auto_planned_payout_date ]
  end

  # ─── 支出：跟著發生日期、手動、改回自動 ─────────────────────────────

  test "關閉付款日、沒手動改過：只改發生日期時應付日期跟著改" do
    @company.update!(payout_day: nil)
    id = create_expense!(date: "2026-11-03")["id"]

    body = update_expense!(id, date: "2026-11-08")
    assert_equal [ "2026-11-08", false ], body.values_at("planned_payout_date", "planned_payout_manual")
  end

  test "由付款日算出的應付日期，不隨發生日期變動" do
    id = create_expense!(date: "2026-11-03")["id"]

    body = update_expense!(id, date: "2026-11-08")
    assert_equal "2026-11-25", body["planned_payout_date"]
  end

  test "送出的應付日期和自動值相同不算手動，不同才算手動；手動後不再跟著發生日期" do
    same = create_expense!(date: "2026-11-03", planned_payout_date: "2026-11-25")
    assert_equal false, same["planned_payout_manual"]

    @company.update!(payout_day: nil)
    body = create_expense!(date: "2026-11-03", planned_payout_date: "2026-11-20")
    assert_equal [ "2026-11-20", true ], body.values_at("planned_payout_date", "planned_payout_manual")

    body = update_expense!(body["id"], date: "2026-11-08")
    assert_equal "2026-11-20", body["planned_payout_date"]
  end

  test "編輯時連同沒改過的應付日期一起送：視為沒改，照樣跟著發生日期" do
    @company.update!(payout_day: nil)
    id = create_expense!(date: "2026-11-03")["id"]

    body = update_expense!(id, date: "2026-11-08", planned_payout_date: "2026-11-03")
    assert_equal [ "2026-11-08", false ], body.values_at("planned_payout_date", "planned_payout_manual")
  end

  test "編輯時手動改過的應付日期原值送回，維持手動" do
    @company.update!(payout_day: nil)
    id = create_expense!(date: "2026-11-03", planned_payout_date: "2026-11-20")["id"]

    body = update_expense!(id, date: "2026-11-08", planned_payout_date: "2026-11-20")
    assert_equal [ "2026-11-20", true ], body.values_at("planned_payout_date", "planned_payout_manual")
  end

  test "同一個日期用編輯或調整應付日期，手動判定相同" do
    a = create_expense!(date: "2026-11-03")["id"]
    b = create_expense!(date: "2026-11-03")["id"]
    %w[2026-12-01 2026-11-25].each do |date|
      assert_equal update_expense!(a, planned_payout_date: date).values_at("planned_payout_date", "planned_payout_manual"),
        adjust!(b, date).values_at("planned_payout_date", "planned_payout_manual")
    end
  end

  test "改回自動排程：編輯送 null 或 adjust 送 null，還原為自動值" do
    id = create_expense!(date: "2026-11-03", planned_payout_date: "2026-12-01")["id"]

    body = update_expense!(id, planned_payout_date: nil)
    assert_equal [ "2026-11-25", false ], body.values_at("planned_payout_date", "planned_payout_manual")

    adjust!(id, "2026-12-05")
    body = adjust!(id, nil)
    assert_equal [ "2026-11-25", false ], body.values_at("planned_payout_date", "planned_payout_manual")
  end

  test "改回自動排程：登錄時已關閉付款日（自動值為 null）→ 409，資料不變" do
    @company.update!(payout_day: nil)
    id = create_expense!(date: "2026-11-03", planned_payout_date: "2026-12-01")["id"]
    @company.update!(payout_day: 25)

    patch "/api/expenses/#{id}/adjust-payout-date", params: { date: nil }, headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert_equal "NO_AUTO_SCHEDULE", response.parsed_body["error"]
    expense = Expense.find(id)
    assert_equal [ Date.new(2026, 12, 1), true, nil ],
      [ expense.planned_payout_date, expense.planned_payout_manual, expense.auto_planned_payout_date ]

    get "/api/expenses", headers: auth_headers(@admin)
    row = response.parsed_body["data"].find { |e| e["id"] == id }
    assert_nil row["auto_planned_payout_date"]
    assert row.key?("auto_planned_payout_date")
  end

  test "調整應付日期：和自動值不同算手動，相同不算；公司之後改付款日不影響既有支出" do
    id = create_expense!(date: "2026-11-03")["id"]

    assert_equal true,  adjust!(id, "2026-12-01")["planned_payout_manual"]
    assert_equal false, adjust!(id, "2026-11-25")["planned_payout_manual"]

    @company.update!(payout_day: 5)
    body = adjust!(id, nil)
    assert_equal [ "2026-11-25", "2026-11-25" ], body.values_at("planned_payout_date", "auto_planned_payout_date")
  end

  # ─── 收入：應收日期 ─────────────────────────────

  test "應收日期預設為發生日期，不看公司付款日" do
    body = create_income!(date: "2026-11-03")
    assert_equal "2026-11-03", body["planned_collection_date"]
  end

  test "只改發生日期：應收日期原本同一天就跟著改，不同就不動" do
    same = create_income!(date: "2026-11-03")
    assert_equal "2026-11-08", update_income!(same["id"], date: "2026-11-08")["planned_collection_date"]

    diff = create_income!(date: "2026-11-03", planned_collection_date: "2026-12-03")
    assert_equal "2026-12-03", update_income!(diff["id"], date: "2026-11-08")["planned_collection_date"]
  end

  test "有送應收日期就照存，即使等於原本的發生日期" do
    id = create_income!(date: "2026-11-03")["id"]

    body = update_income!(id, date: "2026-11-08", planned_collection_date: "2026-11-03")
    assert_equal [ "2026-11-08", "2026-11-03" ], body.values_at("date", "planned_collection_date")
  end

  # ─── 狀態切換 ─────────────────────────────

  test "支出標記已付款沒帶日期時用今天；改回待付款保留實付日期與應付日期" do
    id = create_expense!(date: "2026-11-03", planned_payout_date: "2026-11-05")["id"]

    patch "/api/expenses/#{id}/pay", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal TODAY.iso8601, response.parsed_body["paid_at"]

    patch "/api/expenses/#{id}/revert-pay", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ "pending", TODAY.iso8601, "2026-11-05", true ],
      response.parsed_body.values_at("payout_status", "paid_at", "planned_payout_date", "planned_payout_manual")
  end

  test "收入標記已收款沒帶日期時用今天、有帶用帶的；改回待收款保留實收日期與應收日期" do
    id = create_income!(date: "2026-11-03", planned_collection_date: "2026-11-30")["id"]

    patch "/api/incomes/#{id}/collect", headers: auth_headers(@admin), as: :json
    assert_equal TODAY.iso8601, response.parsed_body["collected_at"]
    patch "/api/incomes/#{id}/revert-collect", headers: auth_headers(@admin), as: :json
    patch "/api/incomes/#{id}/collect", params: { collected_at: "2026-11-09" }, headers: auth_headers(@admin), as: :json
    assert_equal "2026-11-09", response.parsed_body["collected_at"]

    patch "/api/incomes/#{id}/revert-collect", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ "uncollected", "2026-11-09", "2026-11-30" ],
      response.parsed_body.values_at("collection_status", "collected_at", "planned_collection_date")
  end

  # ─── 發票日期 ─────────────────────────────

  test "發票沒填發票日期不可儲存，支出、收入都一樣" do
    post "/api/expenses", params: expense_params(document_type: "invoice", tax_id: "12345678", tax_rate: "business_5"),
      headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "invoice_date").present?

    post "/api/incomes", params: income_params(document_type: "invoice", tax_id: "12345678", tax_rate: "business_5"),
      headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "invoice_date").present?
  end

  test "收據不存發票日期；發票改成收據時清空" do
    receipt = create_expense!(invoice_date: "2026-11-01")
    assert_nil receipt["invoice_date"]

    invoice = create_income!(document_type: "invoice", tax_id: "12345678", tax_rate: "business_5", invoice_date: "2026-11-01")
    assert_equal "2026-11-01", invoice["invoice_date"]
    body = update_income!(invoice["id"], document_type: "receipt", tax_rate: "exempt_0", tax_id: nil)
    assert_nil body["invoice_date"]
  end

  # ─── 代墊款請款的發票日期 ─────────────────────────────

  test "請款：發票送出時沒填發票日期被擋，草稿可以先存" do
    employee = create_user(company: @company)
    post "/api/reimbursements", params: reimbursement_params, headers: auth_headers(employee), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "invoice_date").present?

    post "/api/reimbursements", params: reimbursement_params(as_draft: true), headers: auth_headers(employee), as: :json
    assert_response :created
    draft_id = response.parsed_body["id"]

    patch "/api/reimbursements/#{draft_id}", params: reimbursement_params(invoice_date: "2026-11-02"),
      headers: auth_headers(employee), as: :json
    assert_response :ok
    assert_equal [ "in_review", "2026-11-02" ], response.parsed_body.values_at("status", "invoice_date")
  end

  test "請款：收據不存發票日期；駁回後改成收據重送時清空" do
    employee = create_user(company: @company)
    post "/api/reimbursements", params: reimbursement_params(document_type: "receipt", tax_rate: "exempt_0", tax_id: nil,
      invoice_no: nil), headers: auth_headers(employee), as: :json
    assert_response :created
    assert_nil response.parsed_body["invoice_date"]

    post "/api/reimbursements", params: reimbursement_params(invoice_date: "2026-11-02"), headers: auth_headers(employee), as: :json
    assert_response :created
    r = Reimbursement.find(response.parsed_body["id"])
    r.update_columns(status: "rejected")
    patch "/api/reimbursements/#{r.id}", params: reimbursement_params(document_type: "receipt", tax_rate: "exempt_0",
      tax_id: nil, invoice_no: nil, invoice_date: "2026-11-02"), headers: auth_headers(employee), as: :json
    assert_response :ok
    assert_nil r.reload.invoice_date
  end

  test "請款核准：支出的發生日期、發票日期分別等於請款的發生日期、發票日期" do
    employee = create_user(company: @company)
    post "/api/reimbursements", params: reimbursement_params(incurred_at: "2026-10-28", invoice_date: "2026-11-02"),
      headers: auth_headers(employee), as: :json
    assert_response :created
    id = response.parsed_body["id"]

    patch "/api/reimbursements/#{id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: id)
    assert_equal [ Date.new(2026, 10, 28), Date.new(2026, 11, 2) ], [ expense.date, expense.invoice_date ]
  end

  test "請款 migration：既有的發票請款以發生日期補發票日期，收據不補" do
    employee = create_user(company: @company)
    invoice = create_reimbursement(employee: employee)
    invoice.update_columns(document_type: "invoice", incurred_at: Date.new(2026, 10, 1))
    receipt = create_reimbursement(employee: employee)

    ActiveRecord::Base.connection.execute(AddInvoiceDateToReimbursements::BACKFILL_SQL)

    assert_equal Date.new(2026, 10, 1), invoice.reload.invoice_date
    assert_nil receipt.reload.invoice_date
  end

  # ─── 待收付分組 ─────────────────────────────

  test "待付款分組：逾期合成一組排最前，當天不算逾期，其餘依日期由近到遠" do
    @company.update!(payout_day: nil)
    [ [ "2026-11-01", 100 ], [ "2026-11-09", 200 ], [ "2026-11-10", 300 ], [ "2026-11-20", 400 ], [ "2026-11-20", 500 ] ]
      .each { |date, amount| create_expense!(date: date, amount: amount) }
    create_expense!(date: "2026-11-02", amount: 999, payout_status: "paid")

    get "/api/expenses/pending-batches", headers: auth_headers(@admin)
    assert_response :ok
    groups = response.parsed_body["groups"].map { |g| g.slice("key", "date", "overdue", "total", "count") }
    assert_equal [
      { "key" => "0000-overdue", "date" => "2026-11-01", "overdue" => true,  "total" => 300.0, "count" => 2 },
      { "key" => "2026-11-10",   "date" => "2026-11-10", "overdue" => false, "total" => 300.0, "count" => 1 },
      { "key" => "2026-11-20",   "date" => "2026-11-20", "overdue" => false, "total" => 900.0, "count" => 2 }
    ], groups
  end

  test "待收款分組：依應收日期分組，不含已收款、垃圾桶與別家公司的紀錄" do
    create_income!(date: "2026-11-01", amount: 10)
    create_income!(date: "2026-11-01", planned_collection_date: "2026-11-15", amount: 20)
    create_income!(date: "2026-11-02", amount: 30, collection_status: "collected")
    trashed = create_income!(date: "2026-11-15", amount: 40)
    Income.find(trashed["id"]).discard!

    other   = create_company(name: "他公司")
    other_admin = create_user(company: other, role: "admin")
    post "/api/incomes", params: income_params(date: "2026-11-15", amount: 50, account_id: account_for(other).id,
      category_id: other.categories.of_kind("income").active.first.id), headers: auth_headers(other_admin), as: :json
    assert_response :created

    get "/api/incomes/pending-batches", headers: auth_headers(@admin)
    assert_response :ok
    groups = response.parsed_body["groups"]
    assert_equal [ [ "0000-overdue", 10.0, 1 ], [ "2026-11-15", 20.0, 1 ] ],
      groups.map { |g| g.values_at("key", "total", "count") }
    assert_equal [ 1, 1 ], groups.map { |g| g["rows"].size }
    assert_not groups.first["rows"].first.key?("attachments")
    assert_not groups.first["rows"].first.key?("items")
  end

  test "待收付分組只有管理員可看" do
    employee = create_user(company: @company)
    %w[/api/expenses/pending-batches /api/incomes/pending-batches].each do |path|
      get path, headers: auth_headers(employee)
      assert_response :forbidden
    end
  end

  test "待付款分組只含本公司資料" do
    create_expense!(date: "2026-11-20", amount: 100)
    other = create_company(name: "他公司")
    get "/api/expenses/pending-batches", headers: auth_headers(create_user(company: other, role: "admin"))
    assert_response :ok
    assert_equal [], response.parsed_body["groups"]
  end

  # ─── 既有資料補值後的規則 ─────────────────────────────
  # Migration 把應付日期為 null 的支出、所有收入的應收日期補成發生日期，自動值維持原樣。

  test "補值後：沒有自動值的支出跟著發生日期，有自動值的不動" do
    no_auto = legacy_expense(planned_payout_date: Date.new(2026, 10, 1), auto_planned_payout_date: nil)
    no_auto.update!(date: Date.new(2026, 10, 3))
    assert_equal Date.new(2026, 10, 3), no_auto.planned_payout_date

    with_auto = legacy_expense(planned_payout_date: Date.new(2026, 11, 5), auto_planned_payout_date: Date.new(2026, 11, 5))
    with_auto.update!(date: Date.new(2026, 10, 3))
    assert_equal Date.new(2026, 11, 5), with_auto.planned_payout_date
  end

  test "補值後：手動改過的支出不跟著發生日期；收入應收日期等於發生日期時跟著改" do
    manual = legacy_expense(planned_payout_date: Date.new(2026, 10, 20), auto_planned_payout_date: nil, planned_payout_manual: true)
    manual.update!(date: Date.new(2026, 10, 3))
    assert_equal Date.new(2026, 10, 20), manual.planned_payout_date

    income = @company.incomes.create!(created_by: @admin, category: @income_category, account: @account, customer: "王",
      document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.new(2026, 10, 1),
      planned_collection_date: Date.new(2026, 10, 1))
    income.update!(date: Date.new(2026, 10, 3))
    assert_equal Date.new(2026, 10, 3), income.planned_collection_date
  end

  private

  def expense_params(**attrs)
    { category_id: @expense_category.id, account_id: @account.id, amount: 100, date: "2026-11-03",
      vendor: "甲", document_type: "receipt", tax_rate: "exempt_0" }.merge(attrs)
  end

  def income_params(**attrs)
    { category_id: @income_category.id, account_id: @account.id, amount: 100, date: "2026-11-03",
      customer: "王", document_type: "receipt", tax_rate: "exempt_0" }.merge(attrs)
  end

  def create_expense!(**attrs)
    post "/api/expenses", params: expense_params(**attrs), headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body
  end

  def create_income!(**attrs)
    post "/api/incomes", params: income_params(**attrs), headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body
  end

  def update_expense!(id, **attrs)
    patch "/api/expenses/#{id}", params: attrs, headers: auth_headers(@admin), as: :json
    assert_response :ok
    response.parsed_body
  end

  def update_income!(id, **attrs)
    patch "/api/incomes/#{id}", params: attrs, headers: auth_headers(@admin), as: :json
    assert_response :ok
    response.parsed_body
  end

  def adjust!(id, date)
    patch "/api/expenses/#{id}/adjust-payout-date", params: { date: date }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    response.parsed_body
  end

  def reimbursement_params(**attrs)
    { category_id: @expense_category.id, amount: 105, description: "計程車", incurred_at: "2026-11-01",
      document_type: "invoice", vendor: "車行", tax_id: "12345678", invoice_no: "AB12345678",
      tax_rate: "business_5" }.merge(attrs)
  end

  # 模擬補值後的既有支出：發生日期 10/1，自動值依當時的資料。
  def legacy_expense(**attrs)
    @company.expenses.create!({
      source: "general", created_by: @admin, category: @expense_category, account: @account, vendor: "甲",
      document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.new(2026, 10, 1), payout_status: "pending",
      planned_payout_manual: false
    }.merge(attrs))
  end
end
