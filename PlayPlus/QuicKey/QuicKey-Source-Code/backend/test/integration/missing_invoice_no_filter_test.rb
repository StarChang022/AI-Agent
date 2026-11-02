require "test_helper"

# 支出、收入列表的「未填發票號碼」篩選（PRD 第 17 條）。
class MissingInvoiceNoFilterTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  def create_expense(company: @company, admin: @admin, **attrs)
    company.expenses.create!({
      source: "general", created_by: admin, category: company.categories.of_kind("expense").active.first,
      account: account_for(company), document_type: "invoice", tax_rate: "business_5", tax_id: "12345678",
      amount: 100, date: Date.current, vendor: "甲"
    }.merge(attrs))
  end

  def create_income(company: @company, admin: @admin, **attrs)
    company.incomes.create!({
      created_by: admin, category: company.categories.of_kind("income").active.first,
      account: account_for(company), document_type: "invoice", tax_rate: "business_5", tax_id: "12345678",
      amount: 100, date: Date.current, customer: "甲"
    }.merge(attrs))
  end

  def receipt_attrs
    { document_type: "receipt", tax_rate: "exempt_0", tax_id: nil }
  end

  def expense_ids(params = {})
    get "/api/expenses", params: params, headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body["data"].map { |e| e["id"] }
  end

  def income_ids(params = {})
    get "/api/incomes", params: params, headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body.map { |i| i["id"] }
  end

  test "支出：只列發票且號碼空白，NULL 與空字串都列；未帶或 false 回全部" do
    null_no  = create_expense(invoice_no: nil)
    blank_no = create_expense(invoice_no: "")
    filled   = create_expense(invoice_no: "AB12345678")
    receipt  = create_expense(invoice_no: nil, **receipt_attrs)

    assert_equal [ null_no.id, blank_no.id ].sort, expense_ids(missing_invoice_no: true).sort
    all = [ null_no.id, blank_no.id, filled.id, receipt.id ].sort
    assert_equal all, expense_ids.sort
    assert_equal all, expense_ids(missing_invoice_no: false).sort
  end

  test "收入：只列發票且號碼空白，NULL 與空字串都列；未帶或 false 回全部" do
    null_no  = create_income(invoice_no: nil)
    blank_no = create_income(invoice_no: "")
    filled   = create_income(invoice_no: "AB12345678")
    receipt  = create_income(invoice_no: nil, **receipt_attrs)

    assert_equal [ null_no.id, blank_no.id ].sort, income_ids(missing_invoice_no: true).sort
    all = [ null_no.id, blank_no.id, filled.id, receipt.id ].sort
    assert_equal all, income_ids.sort
    assert_equal all, income_ids(missing_invoice_no: false).sort
  end

  test "不限固定收支：代墊款來源、固定產生的支出都列出，可和其他篩選並用" do
    reimbursed = create_expense(source: "reimbursement", payout_status: "paid")
    recurring  = create_recurring_template(company: @company, created_by: @admin,
      document_type: "invoice", tax_rate: "business_5", tax_id: "12345678", start_month: Date.current.strftime("%Y-%m"), day_of_month: 1)
    RecurringGenerator.call(recurring, today: Date.current)
    generated = recurring.expenses.sole

    assert_equal [ reimbursed.id, generated.id ].sort, expense_ids(missing_invoice_no: true).sort
    assert_equal [ reimbursed.id ], expense_ids(missing_invoice_no: true, source: "reimbursement")
    assert_equal [ generated.id ], expense_ids(missing_invoice_no: true, source: "recurring", payout_status: "pending")
  end

  test "收入可和收款狀態、固定篩選並用" do
    uncollected = create_income(collection_status: "uncollected")
    create_income(collection_status: "collected")

    assert_equal [ uncollected.id ], income_ids(missing_invoice_no: true, collection_status: "uncollected")
    assert_empty income_ids(missing_invoice_no: true, recurring: true)
  end

  test "公司隔離：別家公司的紀錄不列" do
    other = create_company(name: "別家公司")
    other_admin = create_user(company: other, role: "admin")
    create_expense(company: other, admin: other_admin)
    create_income(company: other, admin: other_admin)

    assert_empty expense_ids(missing_invoice_no: true)
    assert_empty income_ids(missing_invoice_no: true)
  end
end
