require "test_helper"

# 已付款支出改付款日時，連動代墊款的發放日跟著改。
class ExpensePaidAtSyncTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @corrected = Date.current - 3
  end

  test "代墊款來源的已付款支出改付款日，代墊款的發放日跟著改" do
    r = create_reimbursement(employee: @employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: account_for(@company).id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    patch "/api/expenses/#{expense.id}/pay", params: { payment_method: "cash" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    notifications_before = @employee.notifications.count

    update_paid_at!(expense)

    r.reload
    assert_equal @corrected, r.paid_at
    assert_equal @corrected.iso8601, r.history.reverse.find { |e| e["type"] == "pay" }["at"]
    assert_equal 1, r.history.count { |e| e["type"] == "pay" }
    log = AuditLog.where(target_id: r.id, action: "update").sole
    assert_equal({ "paid_at" => @corrected.iso8601 }, log.after)
    assert_equal notifications_before, @employee.notifications.count
  end

  test "一般支出改付款日不影響任何代墊款" do
    expense = @company.expenses.create!(
      account: account_for(@company),
      source: "general", created_by: @admin, category: @company.categories.find_by!(kind: "expense"),
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current,
      payout_status: "paid", paid_at: Date.current, paid_by: @admin
    )

    assert_no_difference -> { AuditLog.where(target_type: "reimbursement").count } do
      update_paid_at!(expense)
    end
    assert_equal @corrected, expense.reload.paid_at
  end

  private

  def update_paid_at!(expense)
    patch "/api/expenses/#{expense.id}", params: { paid_at: @corrected.iso8601 }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end
end
