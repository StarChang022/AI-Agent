require "test_helper"

# 標記已付款時的付款日預設：帶的值 > 預計付款日 > 今天。
class ExpensePayDateTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "有預計付款日時，付款日等於預計付款日" do
    expense = pending_expense(planned_payout_date: Date.current - 3)
    pay!(expense)
    assert_equal Date.current - 3, expense.reload.paid_at
  end

  test "沒有預計付款日時，付款日等於今天" do
    expense = pending_expense(planned_payout_date: nil)
    pay!(expense)
    assert_equal Date.current, expense.reload.paid_at
  end

  test "有帶付款日時以帶的為準" do
    expense = pending_expense(planned_payout_date: Date.current - 3)
    pay!(expense, paid_at: (Date.current - 1).iso8601)
    assert_equal Date.current - 1, expense.reload.paid_at
  end

  test "代墊款來源的支出，代墊款與通知的付款日也等於預計付款日" do
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: account_for(@company).id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    expense.update!(planned_payout_date: Date.current - 5)

    pay!(expense, payment_method: "cash")
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
