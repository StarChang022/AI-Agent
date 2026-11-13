require "test_helper"

# 標記已付款時的實付日期：帶的值 > 今天，不看應付日期（PRD 第 10 條）。
class ExpensePayDateTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "沒帶實付日期時為今天，不用應付日期" do
    expense = pending_expense(planned_payout_date: Date.current - 3)
    pay!(expense)
    assert_equal Date.current, expense.reload.paid_at
  end

  test "有帶付款日時以帶的為準" do
    expense = pending_expense(planned_payout_date: Date.current - 3)
    pay!(expense, paid_at: (Date.current - 1).iso8601)
    assert_equal Date.current - 1, expense.reload.paid_at
  end

  test "代墊款來源的支出，代墊款與通知的付款日也等於帶的實付日期" do
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: account_for(@company).id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    pay!(expense, payment_method: "cash", paid_at: (Date.current - 5).iso8601)
    assert_equal Date.current - 5, r.reload.paid_at
    notification = employee.notifications.order(:created_at).last
    assert_equal (Date.current - 5).iso8601, notification.payload["paid_at"]
  end

  private

  def pending_expense(planned_payout_date:)
    @company.expenses.create!(
      account: account_for(@company),
      source: "general", created_by: @admin, category: @company.categories.first,
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current,
      payout_status: "pending", planned_payout_date: planned_payout_date
    )
  end

  def pay!(expense, **body)
    patch "/api/expenses/#{expense.id}/pay", params: body, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end
end
