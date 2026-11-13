require "test_helper"

# 改回待付款時應付日期不變、實付日期保留（PRD 第 10 條）。
class ExpenseRevertPayTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @company.update!(payout_day: 25)
    @admin    = create_user(company: @company, role: "admin")
    @category = @company.categories.find_by!(kind: "expense")
    @planned  = Date.current - 10
  end

  test "實付日期手動更正後改回待付款，應付日期不變、實付日期保留" do
    expense   = pending_expense
    corrected = Date.current - 2

    pay!(expense)
    patch "/api/expenses/#{expense.id}", params: { paid_at: corrected.iso8601 }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    revert_pay!(expense)
    expense.reload
    assert_equal [ "pending", @planned, false, corrected ],
      [ expense.payout_status, expense.planned_payout_date, expense.planned_payout_manual, expense.paid_at ]
    log = AuditLog.where(target_id: expense.id, action: "status_change").order(:created_at).last
    assert_equal corrected.iso8601, log.after["paid_at"]
    assert_not log.after.key?("planned_payout_date")
  end

  test "建立時就是已付款的支出也有應付日期，改回待付款後不變" do
    paid_on = Date.current - 7
    post "/api/expenses", params: {
      category_id: @category.id, account_id: account_for(@company).id, amount: 100, date: Date.current.iso8601,
      document_type: "receipt", tax_rate: "exempt_0", payout_status: "paid", paid_at: paid_on.iso8601
    }, headers: auth_headers(@admin), as: :json
    assert_response :created
    expense = Expense.find(response.parsed_body["id"])
    auto = PayoutSchedule.snapshot(Date.current, 25)
    assert_equal [ auto, auto, false ],
      [ expense.planned_payout_date, expense.auto_planned_payout_date, expense.planned_payout_manual ]

    revert_pay!(expense)
    expense.reload
    assert_equal [ auto, paid_on ], [ expense.planned_payout_date, expense.paid_at ]
  end

  private

  def pending_expense
    @company.expenses.create!(
      account: account_for(@company),
      source: "general", created_by: @admin, category: @category,
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current,
      payout_status: "pending", planned_payout_date: @planned,
      auto_planned_payout_date: @planned, planned_payout_manual: false
    )
  end

  def pay!(expense)
    patch "/api/expenses/#{expense.id}/pay", headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  def revert_pay!(expense)
    patch "/api/expenses/#{expense.id}/revert-pay", headers: auth_headers(@admin), as: :json
    assert_response :ok
  end
end
