require "test_helper"

# 統一編號必填規則（docs/資料模型.md Income taxId，2026-11-10）：
# 收入的買方統編一律選填，發票也可不填（開給個人的發票沒有買方統編），有填須為 8 碼數字；
# 支出的賣方統編維持發票必填。
class IncomeTaxIdTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @account = account_for(@company)
  end

  test "收入發票不填統一編號可以儲存" do
    post "/api/incomes", params: income_params(tax_id: ""), headers: auth_headers(@admin), as: :json
    assert_response :created
    assert_nil @company.incomes.sole.tax_id
  end

  test "收入發票的統一編號填錯格式被擋" do
    post "/api/incomes", params: income_params(tax_id: "1234"), headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "tax_id").present?
    assert_empty @company.incomes
  end

  test "支出發票不填統一編號仍被擋" do
    post "/api/expenses", params: {
      category_id: @company.categories.of_kind("expense").active.first.id, account_id: @account.id,
      amount: 105, date: "2026-11-03", invoice_date: "2026-11-03", vendor: "甲",
      document_type: "invoice", tax_rate: "business_5", invoice_no: "AB-12345678", tax_id: ""
    }, headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert response.parsed_body.dig("details", "tax_id").present?
    assert_empty @company.expenses
  end

  private

  def income_params(**attrs)
    {
      category_id: @company.categories.of_kind("income").active.first.id, account_id: @account.id,
      amount: 105, date: "2026-11-03", invoice_date: "2026-11-03", customer: "王小明",
      document_type: "invoice", tax_rate: "business_5", invoice_no: "AB-12345678"
    }.merge(attrs)
  end
end
