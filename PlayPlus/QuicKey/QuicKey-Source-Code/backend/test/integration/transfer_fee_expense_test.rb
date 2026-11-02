require "test_helper"

# 手續費支出只能經由移轉異動（PRD 第 19 條）。支出 API 的阻擋、列表欄位與上一次使用的帳戶。
class TransferFeeExpenseTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @bank    = create_account(company: @company, name: "永豐", opening_month: Date.new(2026, 1, 1))
    @petty   = create_account(company: @company, name: "零用金", opening_month: Date.new(2026, 1, 1))
  end

  test "編輯、切換狀態、調整付款日、刪除都擋" do
    expense = fee_expense(transfer)
    headers = auth_headers(@admin)
    original = expense.attributes

    patch "/api/expenses/#{expense.id}", params: { amount: 1 }, headers: headers, as: :json
    assert_locked
    patch "/api/expenses/#{expense.id}/pay", headers: headers, as: :json
    assert_locked
    patch "/api/expenses/#{expense.id}/revert-pay", headers: headers, as: :json
    assert_locked
    patch "/api/expenses/#{expense.id}/adjust-payout-date", params: { date: "2026-12-01" }, headers: headers, as: :json
    assert_locked
    delete "/api/expenses/#{expense.id}", headers: headers
    assert_locked

    assert_equal original, expense.reload.attributes
  end

  test "移轉在垃圾桶：手續費支出不可還原，也不可單獨永久刪除" do
    id = transfer
    expense = fee_expense(id)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    patch "/api/expenses/#{expense.id}/restore", headers: auth_headers(@admin)
    assert_locked
    delete "/api/expenses/#{expense.id}/purge", headers: auth_headers(@admin)
    assert_locked
    assert expense.reload.discarded?
  end

  test "手續費改為 0 留下的支出：不可還原，可單獨永久刪除" do
    id = transfer
    expense = fee_expense(id)
    patch "/api/transfers/#{id}", params: { fee: 0 }, headers: auth_headers(@admin), as: :json

    patch "/api/expenses/#{expense.id}/restore", headers: auth_headers(@admin)
    assert_locked

    delete "/api/expenses/#{expense.id}/purge", headers: auth_headers(@admin)
    assert_response :ok
    assert_not Expense.exists?(expense.id)
    log = AuditLog.find_by!(target_id: expense.id, action: "purge")
    assert_equal "transfer_fee", log.before["via"]
    assert Transfer.exists?(id)
  end

  test "移轉在垃圾桶時，手續費改為 0 留下的舊支出仍可單獨永久刪除，目前的不行" do
    id = transfer
    old = fee_expense(id)
    patch "/api/transfers/#{id}", params: { fee: 0 }, headers: auth_headers(@admin), as: :json
    patch "/api/transfers/#{id}", params: { fee: 20 }, headers: auth_headers(@admin), as: :json
    current = Transfer.find(id).fee_expense
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    delete "/api/expenses/#{old.id}/purge", headers: auth_headers(@admin)
    assert_response :ok
    delete "/api/expenses/#{current.id}/purge", headers: auth_headers(@admin)
    assert_locked

    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil current.reload.deleted_at
  end

  test "支出列表、詳情回傳來源與移轉 id，可依來源篩選" do
    id = transfer
    expense = fee_expense(id)
    general = create_general_expense

    get "/api/expenses/#{expense.id}", headers: auth_headers(@admin)
    assert_equal "transfer_fee", response.parsed_body["source"]
    assert_equal id, response.parsed_body["transfer_id"]

    get "/api/expenses", params: { source: "transfer_fee" }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].sole
    assert_equal expense.id, row["id"]
    assert_equal id, row["transfer_id"]
    assert_equal false, row["restorable"]
    assert_equal false, row["purgeable"]

    get "/api/expenses", params: { source: "general" }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].sole
    assert_equal general.id, row["id"]
    assert_nil row["transfer_id"]
    assert_equal true, row["restorable"]
    assert_equal true, row["purgeable"]
  end

  test "垃圾桶列表的 restorable、purgeable：舊支出可永久刪除，目前的不行" do
    id = transfer
    old = fee_expense(id)
    patch "/api/transfers/#{id}", params: { fee: 0 }, headers: auth_headers(@admin), as: :json
    patch "/api/transfers/#{id}", params: { fee: 20 }, headers: auth_headers(@admin), as: :json
    current = Transfer.find(id).fee_expense
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    get "/api/expenses", params: { discarded: true }, headers: auth_headers(@admin)
    rows = response.parsed_body["data"].index_by { |r| r["id"] }

    assert_equal [ false, true ], rows[old.id].values_at("restorable", "purgeable")
    assert_equal [ false, false ], rows[current.id].values_at("restorable", "purgeable")
  end

  test "上一次使用的帳戶不含手續費支出" do
    create_general_expense(account: @petty)
    travel 1.hour
    transfer

    assert_equal @petty.id, @admin.reload.last_used_account.id
  end

  test "一般支出手動選手續費類別：可編輯、刪除、還原、永久刪除，移轉產生的那筆仍鎖定" do
    locked = fee_expense(transfer)
    locked_before = locked.attributes
    other = @company.categories.of_kind("expense").kept.where(system_key: nil).first
    headers = auth_headers(@admin)

    post "/api/expenses", params: { category_id: fee_category.id, account_id: @bank.id, document_type: "receipt",
                                    tax_rate: "exempt_0", amount: 100, date: "2026-11-02" }, headers: headers, as: :json
    assert_response :created
    expense = Expense.find(response.parsed_body["id"])
    assert_equal "general", expense.source
    assert_equal fee_category, expense.category
    assert_nil response.parsed_body["transfer_id"]
    assert_equal [ true, true ], response.parsed_body.values_at("restorable", "purgeable")

    get "/api/expenses", params: { source: "transfer_fee" }, headers: headers
    assert_equal [ locked.id ], response.parsed_body["data"].map { |r| r["id"] }

    patch "/api/expenses/#{expense.id}", params: { amount: 200 }, headers: headers, as: :json
    assert_response :ok
    assert_equal 200, expense.reload.amount

    delete "/api/expenses/#{expense.id}", headers: headers
    assert_response :ok
    assert expense.reload.discarded?

    patch "/api/expenses/#{expense.id}/restore", headers: headers
    assert_response :ok
    assert_not expense.reload.discarded?

    patch "/api/expenses/#{expense.id}", params: { category_id: other.id }, headers: headers, as: :json
    assert_response :ok
    assert_equal other, expense.reload.category

    patch "/api/expenses/#{expense.id}", params: { category_id: fee_category.id }, headers: headers, as: :json
    assert_response :ok
    assert_equal fee_category, expense.reload.category

    delete "/api/expenses/#{expense.id}", headers: headers
    delete "/api/expenses/#{expense.id}/purge", headers: headers
    assert_response :ok
    assert_not Expense.exists?(expense.id)

    assert_still_locked(locked, locked_before)
  end

  test "員工請款選手續費類別：核准後的支出照代墊款規則編輯，移轉產生的那筆仍鎖定" do
    locked = fee_expense(transfer)
    locked_before = locked.attributes
    employee = create_user(company: @company)
    headers = auth_headers(@admin)

    post "/api/reimbursements", params: { category_id: fee_category.id, amount: 100, description: "匯款手續費",
                                          incurred_at: "2026-11-02", document_type: "receipt", tax_rate: "exempt_0" },
                                headers: auth_headers(employee), as: :json
    assert_response :created
    reimbursement = Reimbursement.find(response.parsed_body["id"])

    patch "/api/reimbursements/#{reimbursement.id}/approve", params: { account_id: @bank.id }, headers: headers, as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: reimbursement.id)
    assert_equal "reimbursement", expense.source
    assert_equal fee_category, expense.category

    patch "/api/expenses/#{expense.id}", params: { amount: 120, note: "補差額" }, headers: headers, as: :json
    assert_response :ok
    expense.reload
    assert_equal 120, expense.amount
    assert_equal "補差額", expense.note

    patch "/api/expenses/#{expense.id}/pay", params: { payment_method: "cash" }, headers: headers, as: :json
    assert_response :ok
    assert_equal "paid", reimbursement.reload.status

    patch "/api/expenses/#{expense.id}", params: { paid_at: "2026-11-05" }, headers: headers, as: :json
    assert_response :ok
    assert_equal Date.new(2026, 11, 5), reimbursement.reload.paid_at

    patch "/api/expenses/#{expense.id}/revert-pay", headers: headers, as: :json
    assert_response :ok
    assert_equal "approved", reimbursement.reload.status

    delete "/api/expenses/#{expense.id}", headers: headers
    assert_response :ok
    patch "/api/expenses/#{expense.id}/restore", headers: headers
    assert_response :ok
    assert_not expense.reload.discarded?

    assert_still_locked(locked, locked_before)
  end

  private

  def fee_category
    @company.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY)
  end

  def assert_still_locked(expense, original)
    patch "/api/expenses/#{expense.id}", params: { amount: 1 }, headers: auth_headers(@admin), as: :json
    assert_locked
    delete "/api/expenses/#{expense.id}", headers: auth_headers(@admin)
    assert_locked
    assert_equal original, expense.reload.attributes
  end

  def transfer(fee: 15)
    post "/api/transfers", params: { from_account_id: @bank.id, to_account_id: @petty.id, amount: 5000,
                                     fee: fee, transfer_date: "2026-11-02" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body["id"]
  end

  def fee_expense(transfer_id)
    Transfer.find(transfer_id).fee_expense
  end

  def create_general_expense(account: @bank)
    @company.expenses.create!(source: "general", category: @company.categories.of_kind("expense").active.first,
      account: account, created_by: @admin, document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
  end

  def assert_locked
    assert_response :conflict
    assert_equal "TRANSFER_FEE_LOCKED", response.parsed_body["error"]
    assert response.parsed_body["message"].present?
  end
end
