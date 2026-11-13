require "test_helper"

# 支出垃圾桶（永久刪除 / 還原）與來源代墊款作廢的連動。
class ExpenseTrashVoidTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)

    # 走核准 API 產生來源為代墊款的支出，再移到垃圾桶
    @reimbursement = create_reimbursement(employee: @employee)
    patch "/api/reimbursements/#{@reimbursement.id}/approve", params: { account_id: account_for(@company).id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    @expense = @company.expenses.find_by!(source_ref_id: @reimbursement.id)
    delete "/api/expenses/#{@expense.id}", headers: auth_headers(@admin)
    assert_response :ok
  end

  test "永久刪除時可同時作廢來源代墊款" do
    delete "/api/expenses/#{@expense.id}/purge",
      params: { void_reimbursement: true, void_comment: "重複請款" }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    assert_not Expense.exists?(@expense.id)
    assert_equal "voided", @reimbursement.reload.status
    assert AuditLog.exists?(target_id: @reimbursement.id, action: "void")
  end

  test "永久刪除要作廢但沒填原因回 422，資料不動" do
    delete "/api/expenses/#{@expense.id}/purge",
      params: { void_reimbursement: true, void_comment: "  " }, headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "COMMENT_REQUIRED", response.parsed_body["error"]

    assert Expense.exists?(@expense.id)
    assert_equal "approved", @reimbursement.reload.status
  end

  test "來源代墊款還能作廢時，永久刪除沒勾作廢回 422，資料不動" do
    delete "/api/expenses/#{@expense.id}/purge", headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "VOID_REQUIRED", response.parsed_body["error"]

    assert Expense.exists?(@expense.id)
    assert_equal "approved", @reimbursement.reload.status
  end

  test "來源代墊款已作廢時可以直接永久刪除" do
    patch "/api/reimbursements/#{@reimbursement.id}/void",
      params: { comment: "作廢" }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    delete "/api/expenses/#{@expense.id}/purge", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_not Expense.exists?(@expense.id)
    assert_nil @reimbursement.reload.expense_id
  end

  test "來源代墊款已作廢時不能還原支出" do
    patch "/api/reimbursements/#{@reimbursement.id}/void",
      params: { comment: "作廢" }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    patch "/api/expenses/#{@expense.id}/restore", headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert_equal "REIMBURSEMENT_VOIDED", response.parsed_body["error"]
    assert @expense.reload.discarded?
  end

  test "列表與單筆回傳來源代墊款狀態" do
    get "/api/expenses", params: { discarded: true }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].find { |e| e["id"] == @expense.id }
    assert_equal "approved", row["source_reimbursement_status"]

    patch "/api/expenses/#{@expense.id}/restore", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal "approved", response.parsed_body["source_reimbursement_status"]
  end

  test "別家公司的管理員不能永久刪除或還原" do
    other_admin = create_user(company: create_company(name: "別家公司"), role: "admin")

    delete "/api/expenses/#{@expense.id}/purge",
      params: { void_reimbursement: true, void_comment: "x" }, headers: auth_headers(other_admin), as: :json
    assert_response :not_found
    patch "/api/expenses/#{@expense.id}/restore", headers: auth_headers(other_admin), as: :json
    assert_response :not_found

    assert Expense.exists?(@expense.id)
    assert_equal "approved", @reimbursement.reload.status
  end
end
