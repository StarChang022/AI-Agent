require "test_helper"

# 代墊款品項（docs/資料模型.md §2.1.1、§5.2；PRD 第 23 條「代墊款品項」）：
# 核准時複製成支出的品項、之後兩邊各自獨立；只有申請人本人能在草稿／駁回時改品項。
class ReimbursementItemsTest < ActionDispatch::IntegrationTest
  ITEMS = [
    { "name" => "A4 紙", "quantity" => 2, "unit_price" => 150, "subtotal" => 300 },
    { "name" => "碳粉", "quantity" => 1, "unit_price" => 900, "subtotal" => 900 }
  ].freeze
  OTHER_ITEMS = [ { "name" => "改過的品項", "quantity" => 1, "unit_price" => 50, "subtotal" => 50 } ].freeze

  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @category = @company.categories.of_kind("expense").active.first
  end

  test "核准時品項複製到支出，之後改任一邊，另一邊不受影響" do
    post "/api/reimbursements", params: submit_params.merge(items: ITEMS), headers: auth_headers(@employee), as: :json
    assert_response :created
    id = response.parsed_body["id"]

    # 單筆回品項，列表不回
    get "/api/reimbursements/#{id}", headers: auth_headers(@employee)
    assert_equal ITEMS, response.parsed_body["items"]
    get "/api/reimbursements", headers: auth_headers(@employee)
    assert_not response.parsed_body["data"].first.key?("items")

    patch "/api/reimbursements/#{id}/approve", params: { account_id: account_for(@company).id },
      headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: id)
    assert_equal ITEMS, expense.items

    # 改支出的品項，請款不變
    patch "/api/expenses/#{expense.id}", params: { items: OTHER_ITEMS }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal OTHER_ITEMS, expense.reload.items
    reimbursement = Reimbursement.find(id)
    assert_equal ITEMS, reimbursement.items

    # 請款這邊的品項變了（已核准不能從 API 改，直接改資料），支出也不變
    reimbursement.update!(items: [])
    assert_equal OTHER_ITEMS, expense.reload.items
  end

  test "申請人可以改自己草稿與駁回單的品項" do
    draft = create_reimbursement(employee: @employee, status: "draft")
    patch "/api/reimbursements/#{draft.id}", params: submit_params.merge(as_draft: true, items: ITEMS),
      headers: auth_headers(@employee), as: :json
    assert_response :ok
    assert_equal ITEMS, draft.reload.items

    rejected = create_reimbursement(employee: @employee, status: "rejected")
    rejected.update!(items: ITEMS)
    patch "/api/reimbursements/#{rejected.id}", params: submit_params.merge(items: OTHER_ITEMS),
      headers: auth_headers(@employee), as: :json
    assert_response :ok
    assert_equal [ "in_review", OTHER_ITEMS ], rejected.reload.values_at(:status, :items)
  end

  test "已送審的請款不能改品項" do
    r = create_reimbursement(employee: @employee, status: "in_review")
    r.update!(items: ITEMS)

    patch "/api/reimbursements/#{r.id}", params: submit_params.merge(items: OTHER_ITEMS),
      headers: auth_headers(@employee), as: :json
    assert_response :conflict
    assert_equal "NOT_EDITABLE", response.parsed_body["error"]
    assert_equal ITEMS, r.reload.items
  end

  test "別人的請款改不到品項：同公司其他員工、審核的管理員都被擋" do
    r = create_reimbursement(employee: @employee, status: "draft")
    r.update!(items: ITEMS)
    colleague = create_user(company: @company)

    [ colleague, @admin ].each do |user|
      patch "/api/reimbursements/#{r.id}", params: submit_params.merge(as_draft: true, items: OTHER_ITEMS),
        headers: auth_headers(user), as: :json
      assert_response :not_found
    end
    assert_equal ITEMS, r.reload.items
  end

  test "別家公司看不到也改不到品項" do
    r = create_reimbursement(employee: @employee, status: "draft")
    r.update!(items: ITEMS)
    other = create_company(name: "別家公司")
    outsiders = [ create_user(company: other, role: "admin"), create_user(company: other) ]

    outsiders.each do |user|
      get "/api/reimbursements/#{r.id}", headers: auth_headers(user)
      assert_response :not_found

      patch "/api/reimbursements/#{r.id}", params: submit_params.merge(as_draft: true, items: OTHER_ITEMS),
        headers: auth_headers(user), as: :json
      assert_response :not_found
    end
    assert_equal ITEMS, r.reload.items
  end

  private

  def submit_params
    { category_id: @category.id, amount: 1200, incurred_at: Date.current.iso8601, description: "文具",
      document_type: "receipt", tax_rate: "exempt_0" }
  end
end
