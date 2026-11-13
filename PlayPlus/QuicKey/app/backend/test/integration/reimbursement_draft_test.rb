require "test_helper"

# 請款草稿可以存一半（docs/資料模型.md §4.1）：類別、金額、發生日期在草稿時可空，送出時才擋；
# 員工列表、明細、首頁統計遇到空值不出錯。
class ReimbursementDraftTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @category = @company.categories.of_kind("expense").active.first
    account_for(@company)
  end

  test "草稿沒選類別、沒填金額與發生日期也能存，讀回為空值" do
    post "/api/reimbursements", params: { as_draft: true, description: "還沒填完", document_type: "receipt", tax_rate: "exempt_0" },
      headers: auth_headers(@employee), as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal [ "draft", nil, nil, nil ], body.values_at("status", "category", "amount", "incurred_at")

    get "/api/reimbursements/#{body['id']}", headers: auth_headers(@employee)
    assert_response :ok
    assert_nil response.parsed_body["amount"]
  end

  test "員工列表、首頁統計遇到空值的草稿不出錯" do
    create_blank_draft
    post "/api/reimbursements", params: submit_params, headers: auth_headers(@employee), as: :json
    assert_response :created

    get "/api/reimbursements", headers: auth_headers(@employee)
    assert_response :ok
    assert_equal 2, response.parsed_body["data"].size

    get "/api/reimbursements/my-summary", headers: auth_headers(@employee)
    assert_response :ok
    assert_equal 2, response.parsed_body.dig("counts", "all")
    assert_equal 100.0, response.parsed_body.dig("totals", "in_review")
  end

  test "空白草稿不出現在後台列表與匯出" do
    create_blank_draft

    get "/api/reimbursements/admin", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal [], response.parsed_body["data"]

    post "/api/data-exports", params: { scope: "filtered", kind: "reimbursement" }, headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "NO_RECORDS", response.parsed_body["error"]
  end

  test "草稿送出時，缺類別、金額或發生日期都被擋" do
    id = create_blank_draft

    patch "/api/reimbursements/#{id}", params: submit_params.except(:category_id), headers: auth_headers(@employee), as: :json
    assert_response :unprocessable_content
    assert_equal "CATEGORY_REQUIRED", response.parsed_body["error"]

    patch "/api/reimbursements/#{id}", params: submit_params.except(:amount, :incurred_at), headers: auth_headers(@employee), as: :json
    assert_response :unprocessable_content
    details = response.parsed_body["details"]
    assert details["amount"].present? && details["incurred_at"].present?

    patch "/api/reimbursements/#{id}", params: submit_params, headers: auth_headers(@employee), as: :json
    assert_response :ok
    assert_equal "in_review", response.parsed_body["status"]
  end

  private

  def submit_params
    { category_id: @category.id, amount: 100, incurred_at: Date.current.iso8601, description: "計程車",
      document_type: "receipt", tax_rate: "exempt_0" }
  end

  def create_blank_draft
    post "/api/reimbursements", params: { as_draft: true, document_type: "receipt", tax_rate: "exempt_0" },
      headers: auth_headers(@employee), as: :json
    assert_response :created
    response.parsed_body["id"]
  end
end
