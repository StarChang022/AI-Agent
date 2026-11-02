require "test_helper"

# 改回待付款時，預計付款日改成原本的付款日（含手動更正），再次付款沿用它。
class ExpenseRevertPayTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @company.update!(payout_day: 25)
    @admin    = create_user(company: @company, role: "admin")
    @category = @company.categories.find_by!(kind: "expense")
    @planned  = Date.current - 10
  end

  test "付款日手動更正後改回待付款，再次付款沿用更正後的日期" do
    expense   = pending_expense
    corrected = Date.current - 2

    pay!(expense)
    assert_equal @planned, expense.reload.paid_at

    patch "/api/expenses/#{expense.id}", params: { paid_at: corrected.iso8601 }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    revert_pay!(expense)
    expense.reload
    assert_equal corrected, expense.planned_payout_date
    assert expense.planned_payout_manual
    assert_equal @planned, expense.auto_planned_payout_date

    log = AuditLog.where(target_id: expense.id, action: "status_change").order(:created_at).last
    assert_equal @planned.iso8601,  log.before["planned_payout_date"]
    assert_equal corrected.iso8601, log.after["planned_payout_date"]
    assert_equal false, log.before["planned_payout_manual"]
    assert_equal true,  log.after["planned_payout_manual"]

    pay!(expense)
    assert_equal corrected, expense.reload.paid_at
  end

  test "付款日沒改過時改回待付款，預計付款日不變也不鎖定" do
    expense = pending_expense
    pay!(expense)
    revert_pay!(expense)

    expense.reload
    assert_equal @planned, expense.planned_payout_date
    assert_not expense.planned_payout_manual
  end

  test "建立時就是已付款的支出，改回待付款後預計付款日等於原付款日" do
    paid_on = Date.current - 7
    post "/api/expenses", params: {
      category_id: @category.id, account_id: account_for(@company).id, amount: 100, date: Date.current.iso8601,
      document_type: "receipt", tax_rate: "exempt_0", payout_status: "paid", paid_at: paid_on.iso8601
    }, headers: auth_headers(@admin), as: :json
    assert_response :created
    expense = Expense.find(response.parsed_body["id"])

    revert_pay!(expense)
    expense.reload
    auto = PayoutSchedule.snapshot(Date.current, 25)
    assert_equal paid_on, expense.planned_payout_date
    assert_equal auto, expense.auto_planned_payout_date
    assert_equal paid_on != auto, expense.planned_payout_manual
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
