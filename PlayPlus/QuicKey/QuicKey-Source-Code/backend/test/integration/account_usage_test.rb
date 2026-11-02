require "test_helper"

# 收支與帳戶（PRD 規則 20）：寫入路徑都要帶帳戶、公司隔離、上一次使用的帳戶、代墊款核准。
class AccountUsageTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @account = create_account(company: @company, name: "主帳戶")
    @expense_category = @company.categories.find_by!(kind: "expense", name: "交通費")
    @income_category  = @company.categories.find_by!(kind: "income", name: "銷售收入")
  end

  test "新增支出、收入沒帶帳戶 → 422，待付款、待收款也一樣" do
    post_expense
    assert_response :unprocessable_content
    assert_equal "ACCOUNT_REQUIRED", response.parsed_body["error"]
    assert_equal "請選擇帳戶", response.parsed_body["message"]

    post_income(collection_status: "uncollected")
    assert_response :unprocessable_content
    assert_equal "ACCOUNT_REQUIRED", response.parsed_body["error"]
    assert_equal 0, @company.expenses.count + @company.incomes.count
  end

  test "別家公司或垃圾桶內的帳戶 → 422，不建立" do
    foreign = create_account(company: create_company(name: "別家"))
    trashed = create_account(company: @company, name: "已刪除")
    trashed.discard!

    [ foreign, trashed ].each do |account|
      post_expense(account_id: account.id)
      assert_response :unprocessable_content
      assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]

      post_income(account_id: account.id)
      assert_response :unprocessable_content
      assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    end
    assert_equal 0, @company.expenses.count + @company.incomes.count
  end

  test "模型層也擋跨公司帳戶" do
    foreign = create_account(company: create_company(name: "別家"))
    expense = @company.expenses.new(account: foreign, source: "general", created_by: @admin,
      category: @expense_category, document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    assert_not expense.valid?
    assert expense.errors.key?(:account_id)
  end

  test "新增後列表與單筆都回帳戶" do
    post_expense(account_id: @account.id)
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal({ "id" => @account.id, "name" => "主帳戶" }, response.parsed_body["account"])

    get "/api/expenses", headers: auth_headers(@admin)
    assert_equal "主帳戶", response.parsed_body["data"].sole.dig("account", "name")
    get "/api/expenses/#{id}", headers: auth_headers(@admin)
    assert_equal "主帳戶", response.parsed_body.dig("account", "name")
  end

  test "編輯可改帳戶，稽核有新舊名稱；已付款也可以改" do
    other = create_account(company: @company, name: "零用金")
    post_expense(account_id: @account.id, payout_status: "paid")
    expense = Expense.find(response.parsed_body["id"])

    patch "/api/expenses/#{expense.id}", params: { account_id: other.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal other.id, expense.reload.account_id

    log = AuditLog.where(target_type: "expense", target_id: expense.id, action: "update").sole
    assert_equal "主帳戶", log.before["account_name"]
    assert_equal "零用金", log.after["account_name"]
  end

  test "編輯時清空帳戶或換成別家帳戶 → 422，帳戶不變" do
    post_income(account_id: @account.id)
    income = Income.find(response.parsed_body["id"])
    foreign = create_account(company: create_company(name: "別家"))

    patch "/api/incomes/#{income.id}", params: { account_id: nil }, headers: auth_headers(@admin), as: :json
    assert_equal "ACCOUNT_REQUIRED", response.parsed_body["error"]
    patch "/api/incomes/#{income.id}", params: { account_id: foreign.id }, headers: auth_headers(@admin), as: :json
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    assert_equal @account.id, income.reload.account_id
  end

  test "編輯沒帶帳戶時保留原帳戶" do
    post_expense(account_id: @account.id)
    expense = Expense.find(response.parsed_body["id"])

    patch "/api/expenses/#{expense.id}", params: { note: "改說明" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal @account.id, expense.reload.account_id
  end

  test "上一次使用的帳戶：從未用過為空，支出收入共用，取最後建立的一筆" do
    assert_nil last_used_account_id

    petty = create_account(company: @company, name: "零用金")
    post_expense(account_id: @account.id)
    assert_equal @account.id, last_used_account_id
    post_income(account_id: petty.id)
    assert_equal petty.id, last_used_account_id
  end

  test "上一次使用的帳戶：排除垃圾桶內的紀錄，帶入該筆目前的帳戶" do
    petty = create_account(company: @company, name: "零用金")
    bank  = create_account(company: @company, name: "銀行")
    post_expense(account_id: @account.id)
    older = Expense.find(response.parsed_body["id"])
    post_income(account_id: petty.id)
    newest = Income.find(response.parsed_body["id"])
    assert_equal petty.id, last_used_account_id

    delete "/api/incomes/#{newest.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal @account.id, last_used_account_id, "最新一筆在垃圾桶，改看前一筆"

    patch "/api/expenses/#{older.id}", params: { account_id: bank.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal bank.id, last_used_account_id, "帶該筆目前的帳戶"
  end

  test "上一次使用的帳戶：全部進垃圾桶後為空" do
    post_expense(account_id: @account.id)
    delete "/api/expenses/#{response.parsed_body["id"]}", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil last_used_account_id
  end

  test "收支不能指定垃圾桶內的帳戶，模型層也擋（並發時的最後一道）" do
    trashed = create_account(company: @company, name: "已刪除")
    trashed.discard!
    expense = @company.expenses.new(account: trashed, source: "general", created_by: @admin,
      category: @expense_category, document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    assert_not expense.valid?
    assert expense.errors.key?(:account_id)

    income = @company.incomes.new(account: trashed, created_by: @admin, customer: "王",
      category: @income_category, document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    assert_not income.valid?
    assert income.errors.key?(:account_id)
  end

  test "編輯時改到垃圾桶帳戶被模型擋；不改帳戶的編輯不受影響" do
    post_expense(account_id: @account.id)
    expense = Expense.find(response.parsed_body["id"])
    trashed = create_account(company: @company, name: "已刪除")
    trashed.discard!

    assert_not expense.update(account: trashed)
    expense.reload
    assert expense.update(note: "改說明")
  end

  test "上一次使用的帳戶已刪除 → 回空，不帶出已刪除的帳戶" do
    petty = create_account(company: @company, name: "零用金")
    post_expense(account_id: petty.id)
    expense = Expense.find(response.parsed_body["id"])

    # 有引用時不能刪，所以用「紀錄還在、帳戶被直接標記刪除」模擬最壞情況
    petty.discard!
    assert_nil last_used_account_id
    assert_equal petty.id, expense.reload.account_id
  end

  test "上一次使用的帳戶是每位使用者各自的" do
    post_expense(account_id: @account.id)
    other_admin = create_user(company: @company, role: "admin")
    assert_nil other_admin.last_used_account
  end

  test "核准代墊款要指定帳戶，連動支出寫入該帳戶，撥款沿用" do
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)

    patch "/api/reimbursements/#{r.id}/approve", headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "ACCOUNT_REQUIRED", response.parsed_body["error"]
    assert_equal "in_review", r.reload.status
    assert_equal 0, @company.expenses.count

    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal "主帳戶", response.parsed_body.dig("linked_expense", "account", "name")

    expense = @company.expenses.find_by!(source_ref_id: r.id)
    assert_equal @account.id, expense.account_id
    assert_equal @account.id, last_used_account_id

    patch "/api/expenses/#{expense.id}/pay", params: { payment_method: "cash" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal @account.id, expense.reload.account_id
  end

  test "核准時帶別家帳戶 → 422，狀態不動" do
    r = create_reimbursement(employee: create_user(company: @company))
    foreign = create_account(company: create_company(name: "別家"))

    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: foreign.id }, headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    assert_equal "in_review", r.reload.status
  end

  test "員工看自己的請款不會拿到帳戶" do
    employee = create_user(company: @company)
    r = create_reimbursement(employee: employee)
    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    get "/api/reimbursements/#{r.id}", headers: auth_headers(employee)
    assert_response :ok
    assert_not_nil response.parsed_body["linked_expense"]
    assert_not response.parsed_body["linked_expense"].key?("account")
  end

  private

  def post_expense(**extra)
    post "/api/expenses", params: {
      category_id: @expense_category.id, amount: 100, date: Date.current.iso8601,
      document_type: "receipt", tax_rate: "exempt_0"
    }.merge(extra), headers: auth_headers(@admin), as: :json
  end

  def post_income(**extra)
    post "/api/incomes", params: {
      category_id: @income_category.id, customer: "王", amount: 100, date: Date.current.iso8601,
      document_type: "receipt", tax_rate: "exempt_0"
    }.merge(extra), headers: auth_headers(@admin), as: :json
  end

  def last_used_account_id
    get "/api/accounts/options", headers: auth_headers(@admin)
    response.parsed_body["last_used_account_id"]
  end
end
