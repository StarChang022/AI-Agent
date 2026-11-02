require "test_helper"

# 類別垃圾桶（PRD 第 18 條、資料模型 §4.3）：刪除條件、清預算、還原、永久刪除、
# 名稱佔用、下拉與匯入排除、使用判斷、權限、公司隔離。
class CategoryTrashTest < ActionDispatch::IntegrationTest
  Category.prepend(BeforeLock)

  setup do
    travel_to Time.zone.local(2026, 11, 11, 12)
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @category = @company.categories.of_kind("expense").active.first
    @headers  = auth_headers(@admin)
  end

  def template(**attrs)
    create_recurring_template(company: @company, created_by: @admin, category: @category, **attrs)
  end

  def list(params = {})
    get "/api/categories", params: { kind: "expense", include_usage: true }.merge(params), headers: @headers
    response.parsed_body
  end

  def row(params = {})
    list(params).find { |c| c["id"] == @category.id }
  end

  def expense_for(category, **attrs)
    @company.expenses.create!({ source: "general", created_by: @admin, category: category, account: account_for(@company),
      document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current, vendor: "甲" }.merge(attrs))
  end

  def set_budgets
    @company.budget_templates.create!(category: @category, cycle: "month", amount: 100)
    @past = @company.budgets.create!(category: @category, cycle: "month", amount: 100,
      period_start: Date.new(2026, 10, 1), period_end: Date.new(2026, 10, 31))
    @current = @company.budgets.create!(category: @category, cycle: "month", amount: 100,
      period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 30))
  end

  test "刪除進垃圾桶，比照停用清預算，is_archived 不動，寫稽核" do
    set_budgets

    delete "/api/categories/#{@category.id}", headers: @headers
    assert_response :ok

    @category.reload
    assert @category.discarded?
    assert_not @category.is_archived
    assert_equal [ @past.id ], @category.budgets.pluck(:id)
    assert_empty @category.budget_templates
    assert_equal "delete", AuditLog.where(target_type: "category", target_id: @category.id).sole.action
  end

  test "已被紀錄使用的類別可以進垃圾桶，既有紀錄仍顯示原名" do
    expense = expense_for(@category)

    delete "/api/categories/#{@category.id}", headers: @headers
    assert_response :ok

    get "/api/expenses/#{expense.id}", headers: @headers
    assert_equal @category.name, response.parsed_body["category"]["name"]
  end

  test "進行中範本使用的類別不可刪除、不可停用" do
    t = template(day_of_month: 20)

    delete "/api/categories/#{@category.id}", headers: @headers
    assert_response :conflict
    assert_equal "CATEGORY_IN_USE_BY_TEMPLATE", response.parsed_body["error"]
    assert_equal [ t.id ], response.parsed_body["templates"].map { |x| x["id"] }

    patch "/api/categories/#{@category.id}/archive", headers: @headers
    assert_response :conflict
    assert_equal "CATEGORY_IN_USE_BY_TEMPLATE", response.parsed_body["error"]
    assert_not @category.reload.is_archived

    res = row
    assert_not res["deletable"]
    assert_not res["archivable"]
    assert_equal 1, res["active_template_count"]
    assert res["blocked_reason"].present?
  end

  test "歷史或垃圾桶內的範本不擋刪除與停用" do
    template(start_month: "2026-01", end_month: "2026-02", last_generated_period: "2026-02")
    template(day_of_month: 20).discard!

    assert row["deletable"]
    assert row["archivable"]

    patch "/api/categories/#{@category.id}/archive", headers: @headers
    assert_response :ok
    delete "/api/categories/#{@category.id}", headers: @headers
    assert_response :ok
  end

  test "每年週期的範本有下一期就算進行中，沒有就不擋" do
    t = template(frequency: "yearly", month_of_year: 12, day_of_month: 5, start_month: "2026-01", end_month: "2026-12")
    assert_not row["deletable"]

    t.update!(last_generated_period: "2026-12")
    assert row["deletable"]
  end

  test "垃圾桶列表帶刪除時間與操作人，不出現在一般列表；可依類型分開" do
    expense_for(@category)
    delete "/api/categories/#{@category.id}", headers: @headers

    assert_nil row
    assert_nil row(archived: true)

    get "/api/categories/trash", params: { kind: "expense" }, headers: @headers
    res = response.parsed_body
    item = res["data"].sole
    assert_equal @category.id, item["id"]
    assert item["deleted_at"].present?
    assert_equal @admin.id, item["deleted_by"]["id"]
    assert_equal 1, item["references"]["expenses"]
    assert_not item["purgeable"]
    assert_equal({ "total" => 1, "page" => 1, "page_size" => 10 }, res["meta"])

    get "/api/categories/trash", params: { kind: "income" }, headers: @headers
    assert_empty response.parsed_body["data"]
  end

  test "還原回到原本狀態，原本停用的仍為停用，預算不恢復，寫稽核" do
    set_budgets
    @category.update!(is_archived: true)
    delete "/api/categories/#{@category.id}", headers: @headers

    travel 1.minute
    patch "/api/categories/#{@category.id}/restore", headers: @headers

    assert_response :ok
    assert_nil response.parsed_body["deleted_at"]
    assert response.parsed_body["is_archived"]
    assert_equal [ @past.id ], @category.budgets.pluck(:id)
    assert_empty @category.budget_templates
    assert_equal %w[delete restore], AuditLog.where(target_type: "category", target_id: @category.id).order(:created_at).pluck(:action)
  end

  test "永久刪除：沒有引用時移除，稽核保存內容" do
    name = @category.name
    @category.discard!

    delete "/api/categories/#{@category.id}/purge", headers: @headers

    assert_response :ok
    assert_not Category.exists?(@category.id)
    assert_equal name, AuditLog.where(target_type: "category", target_id: @category.id, action: "purge").sole.before["name"]
  end

  test "永久刪除：不在垃圾桶回 404" do
    delete "/api/categories/#{@category.id}/purge", headers: @headers
    assert_response :not_found
  end

  test "永久刪除：被支出、代墊款、範本、過往預算使用都不可，含垃圾桶內的紀錄" do
    purge = lambda do
      delete "/api/categories/#{@category.id}/purge", headers: @headers
      assert_response :conflict
      assert_equal "CATEGORY_IN_USE", response.parsed_body["error"]
      response.parsed_body["references"]
    end
    @category.discard!

    expense = expense_for(@category)
    expense.discard!
    assert_equal 1, purge.call["expenses"]
    expense.destroy!

    employee = create_user(company: @company)
    reimbursement = @company.reimbursements.create!(employee: employee, status: "in_review", amount: 100,
      incurred_at: Date.current, category: @category, description: "x", document_type: "receipt", tax_rate: "exempt_0")
    assert_equal 1, purge.call["reimbursements"]
    reimbursement.destroy!

    @category.restore_from_trash!
    t = template(day_of_month: 20)
    t.discard!
    @category.discard!
    assert_equal 1, purge.call["recurring_templates"]
    t.destroy!

    budget = @company.budgets.create!(category: @category, cycle: "month", amount: 100,
      period_start: Date.new(2026, 10, 1), period_end: Date.new(2026, 10, 31))
    assert_equal 1, purge.call["budgets"]
    budget.destroy!

    delete "/api/categories/#{@category.id}/purge", headers: @headers
    assert_response :ok
  end

  test "永久刪除等鎖時類別剛被還原：不刪，回 404，不寫稽核" do
    @category.discard!
    BeforeLock.hook = -> { Category.find(@category.id).update_columns(deleted_at: nil) }

    delete "/api/categories/#{@category.id}/purge", headers: @headers

    assert_response :not_found
    assert Category.exists?(@category.id)
    assert_not AuditLog.exists?(target_id: @category.id, action: "purge")
  end

  test "重複送出刪除：第二次等鎖時已在垃圾桶，回成功但不多寫稽核" do
    BeforeLock.hook = -> { Category.find(@category.id).update_columns(deleted_at: 1.hour.ago) }

    delete "/api/categories/#{@category.id}", headers: @headers

    assert_response :ok
    assert_not AuditLog.exists?(target_id: @category.id, action: "delete")
  end

  test "重複送出還原：第二次等鎖時已還原，回成功但不多寫稽核" do
    @category.discard!
    BeforeLock.hook = -> { Category.find(@category.id).update_columns(deleted_at: nil) }

    patch "/api/categories/#{@category.id}/restore", headers: @headers

    assert_response :ok
    assert_not AuditLog.exists?(target_id: @category.id, action: "restore")
  end

  test "永久刪除：被收入使用不可" do
    income_category = @company.categories.of_kind("income").active.first
    income = @company.incomes.create!(created_by: @admin, category: income_category, account: account_for(@company),
      customer: "甲", document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    income_category.discard!

    delete "/api/categories/#{income_category.id}/purge", headers: @headers

    assert_response :conflict
    assert_equal 1, response.parsed_body["references"]["incomes"]
    assert income.reload
  end

  test "使用筆數：收入類別會算收入，支出類別含支出、代墊款、範本、過往預算；當期預算不算" do
    income_category = @company.categories.of_kind("income").active.first
    @company.incomes.create!(created_by: @admin, category: income_category, account: account_for(@company),
      customer: "甲", document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)

    get "/api/categories", params: { kind: "income", include_usage: true }, headers: @headers
    assert_equal 1, response.parsed_body.find { |c| c["id"] == income_category.id }["usage_count"]

    set_budgets
    expense_for(@category).discard!
    create_reimbursement(employee: create_user(company: @company)).update!(category: @category)
    template(day_of_month: 20)

    res = row
    assert_equal({ "expenses" => 1, "incomes" => 0, "reimbursements" => 1, "recurring_templates" => 1, "budgets" => 1 },
                 res["references"])
    assert_equal 4, res["usage_count"]
    assert_not res["purgeable"]
  end

  test "名稱唯一性含垃圾桶：新增、改名都撞名，訊息請使用者去還原或永久刪除" do
    @category.discard!

    post "/api/categories", params: { kind: "expense", name: @category.name.upcase }, headers: @headers, as: :json
    assert_response :conflict
    res = response.parsed_body
    assert_equal "DUPLICATE_NAME", res["error"]
    assert res["category"]["deleted_at"].present?
    assert_includes res["message"], "垃圾桶"

    other = @company.categories.of_kind("expense").active.first
    patch "/api/categories/#{other.id}", params: { name: @category.name }, headers: @headers, as: :json
    assert_response :conflict
    assert_equal "DUPLICATE_NAME", response.parsed_body["error"]
  end

  test "另一種類型可以和垃圾桶內的類別同名" do
    @category.discard!

    post "/api/categories", params: { kind: "income", name: @category.name }, headers: @headers, as: :json

    assert_response :created
  end

  test "垃圾桶內不可編輯、停用、重新排序" do
    @category.discard!

    patch "/api/categories/#{@category.id}", params: { name: "新名稱" }, headers: @headers, as: :json
    assert_response :not_found
    patch "/api/categories/#{@category.id}/archive", headers: @headers
    assert_response :not_found
    patch "/api/categories/#{@category.id}/unarchive", headers: @headers
    assert_response :not_found
    patch "/api/categories/reorder", params: { ids: [ @category.id ] }, headers: @headers, as: :json
    assert_response :unprocessable_content
  end

  test "新增支出、預算不可選垃圾桶內的類別；編輯既有紀錄類別沒換不擋，換成別的垃圾桶類別才擋" do
    other = @company.categories.of_kind("expense").active.second
    expense = expense_for(@category)
    expense_other = expense_for(other)
    @category.discard!

    post "/api/expenses", params: { category_id: @category.id, account_id: account_for(@company).id, document_type: "receipt",
      tax_rate: "exempt_0", amount: 10, date: Date.current, vendor: "乙" }, headers: @headers, as: :json
    assert_response :unprocessable_content
    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]

    post "/api/budgets", params: { category_id: @category.id, cycle: "month", amount: 10,
      period_start: "2026-12-01", period_end: "2026-12-31" }, headers: @headers, as: :json
    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]

    put "/api/budget-templates", params: { category_id: @category.id, cycle: "month", amount: 10 }, headers: @headers, as: :json
    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]

    patch "/api/expenses/#{expense.id}", params: { category_id: @category.id, amount: 20 }, headers: @headers, as: :json
    assert_response :ok

    patch "/api/expenses/#{expense_other.id}", params: { category_id: @category.id }, headers: @headers, as: :json
    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]
  end

  test "新增收入不可選垃圾桶內的類別" do
    income_category = @company.categories.of_kind("income").active.first
    income_category.discard!

    post "/api/incomes", params: { category_id: income_category.id, account_id: account_for(@company).id,
      document_type: "receipt", tax_rate: "exempt_0", amount: 10, date: Date.current, customer: "乙" }, headers: @headers, as: :json

    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]
  end

  test "員工送出代墊款不可選垃圾桶內的類別，下拉也看不到" do
    employee = create_user(company: @company)
    @category.discard!

    get "/api/categories", params: { kind: "expense" }, headers: auth_headers(employee)
    assert_not_includes response.parsed_body.map { |c| c["id"] }, @category.id

    post "/api/reimbursements", params: { category_id: @category.id, amount: 10, description: "x", incurred_at: Date.current,
      document_type: "receipt", tax_rate: "exempt_0", as_draft: true }, headers: auth_headers(employee), as: :json
    assert_equal "CATEGORY_NOT_FOUND", response.parsed_body["error"]
  end

  test "員工不可使用垃圾桶" do
    employee = create_user(company: @company)

    delete "/api/categories/#{@category.id}", headers: auth_headers(employee)
    assert_response :forbidden
    get "/api/categories/trash", params: { kind: "expense" }, headers: auth_headers(employee)
    assert_response :forbidden
    @category.discard!
    patch "/api/categories/#{@category.id}/restore", headers: auth_headers(employee)
    assert_response :forbidden
    delete "/api/categories/#{@category.id}/purge", headers: auth_headers(employee)
    assert_response :forbidden
  end

  test "公司隔離：別家公司的類別當成找不到" do
    other_company = create_company(name: "別家公司")
    other = other_company.categories.of_kind("expense").active.first
    other_trashed = other_company.categories.of_kind("expense").active.second
    other_trashed.discard!

    delete "/api/categories/#{other.id}", headers: @headers
    assert_response :not_found
    patch "/api/categories/#{other_trashed.id}/restore", headers: @headers
    assert_response :not_found
    delete "/api/categories/#{other_trashed.id}/purge", headers: @headers
    assert_response :not_found
    get "/api/categories/trash", params: { kind: "expense" }, headers: @headers
    assert_empty response.parsed_body["data"]
  end
end
