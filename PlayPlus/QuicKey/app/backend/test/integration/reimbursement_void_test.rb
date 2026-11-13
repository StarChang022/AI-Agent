require "test_helper"

# 代墊款作廢 / 取消作廢：連動支出進出垃圾桶，取消作廢回到作廢前的狀態。
class ReimbursementVoidTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
  end

  test "作廢已核准的單，對應支出一律進垃圾桶" do
    r, expense = approved_reimbursement_with_expense
    void!(r)

    assert_equal "voided", r.reload.status
    assert expense.reload.discarded?
  end

  test "取消作廢回到簽核中" do
    r = create_reimbursement(employee: @employee, status: "in_review")
    void!(r)
    revert_void!(r)
    assert_equal "in_review", r.reload.status
  end

  test "取消作廢回到駁回" do
    r = create_reimbursement(employee: @employee, status: "in_review")
    patch "/api/reimbursements/#{r.id}/reject", params: { comment: "缺憑證" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    void!(r)
    revert_void!(r)
    assert_equal "rejected", r.reload.status
  end

  test "已核准的單取消作廢後回到已核准，支出從垃圾桶還原" do
    r, expense = approved_reimbursement_with_expense
    void!(r)
    revert_void!(r)

    assert_equal "approved", r.reload.status
    assert_not expense.reload.discarded?
    assert AuditLog.exists?(target_id: expense.id, action: "restore")
  end

  test "取消作廢寫入取消作廢的稽核日誌" do
    r = create_reimbursement(employee: @employee, status: "in_review")
    void!(r)
    revert_void!(r)

    log = AuditLog.where(target_id: r.id, action: "revert_void").sole
    assert_equal({ "status" => "voided" }, log.before)
    assert_equal({ "status" => "in_review" }, log.after)
  end

  test "已核准的單作廢後支出被永久刪除，取消作廢回 409，狀態不動" do
    r, expense = approved_reimbursement_with_expense
    void!(r)
    delete "/api/expenses/#{expense.id}/purge", headers: auth_headers(@admin), as: :json
    assert_response :ok

    patch "/api/reimbursements/#{r.id}/revert-void", headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert_equal "LINKED_EXPENSE_PURGED", response.parsed_body["error"]
    assert_equal "voided", r.reload.status
  end

  test "從支出端刪除時作廢，取消作廢同樣回到已核准並還原支出" do
    r, expense = approved_reimbursement_with_expense
    delete "/api/expenses/#{expense.id}",
      params: { void_reimbursement: true, void_comment: "重複請款" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    revert_void!(r)

    assert_equal "approved", r.reload.status
    assert_not expense.reload.discarded?
  end

  private

  def approved_reimbursement_with_expense
    r = create_reimbursement(employee: @employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: account_for(@company).id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    [ r, @company.expenses.find_by!(source_ref_id: r.id) ]
  end

  def void!(r)
    patch "/api/reimbursements/#{r.id}/void", params: { comment: "作廢原因" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  def revert_void!(r)
    patch "/api/reimbursements/#{r.id}/revert-void", headers: auth_headers(@admin), as: :json
    assert_response :ok
  end
end
