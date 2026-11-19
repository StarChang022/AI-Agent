require "test_helper"

# 預算納入稽核日誌（docs/資料模型.md §2.7、§3.5）：三支預算 API、套用基本預算、
# 類別停用與刪除連帶清除、稽核日誌頁的對象名稱與來源、公司隔離。
class BudgetAuditTest < ActionDispatch::IntegrationTest
  Budget.prepend(BeforeLock)

  teardown { BeforeLock.hook = nil }

  setup do
    travel_to Time.zone.local(2026, 11, 15, 10)
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @category = @company.categories.create!(kind: "expense", name: "差旅", account_code: "", sort_order: 99)
    @headers  = auth_headers(@admin)
  end

  # ─── 預算 API ─────────────────────────────

  test "設定預算寫 create，內容為完整快照" do
    post "/api/budgets", params: { category_id: @category.id, cycle: "month", amount: 500,
      period_start: "2026-11-01", period_end: "2026-11-30" }, headers: @headers, as: :json
    assert_response :created

    log = budget_logs.sole
    assert_equal [ "create", @admin, response.parsed_body["id"] ], [ log.action, log.actor, log.target_id ]
    assert_nil log.before
    assert_equal({ "category_id" => @category.id, "category_name" => "差旅", "cycle" => "month",
                   "period_start" => "2026-11-01", "period_end" => "2026-11-30", "amount" => 500.0 }, log.after)
  end

  test "設定失敗不寫" do
    budget!(amount: 100)
    post "/api/budgets", params: { category_id: @category.id, cycle: "month", amount: 500,
      period_start: "2026-11-01", period_end: "2026-11-30" }, headers: @headers, as: :json
    assert_response :conflict
    assert_empty budget_logs
  end

  test "修改金額寫 update，金額相同不寫" do
    budget = budget!(amount: 100)
    patch "/api/budgets/#{budget.id}", params: { amount: 300 }, headers: @headers, as: :json
    assert_response :success
    log = budget_logs.sole
    assert_equal [ "update", { "amount" => 100.0 }, { "amount" => 300.0 } ], [ log.action, log.before, log.after ]

    patch "/api/budgets/#{budget.id}", params: { amount: 300 }, headers: @headers, as: :json
    assert_response :success
    assert_equal 1, budget_logs.count
  end

  test "清除寫 delete，before 為完整快照，after 為空" do
    budget = budget!(amount: 100)
    delete "/api/budgets/#{budget.id}", headers: @headers
    assert_response :success
    assert_nil Budget.find_by(id: budget.id)

    log = budget_logs.sole
    assert_equal "delete", log.action
    assert_nil log.after
    assert_equal 100.0, log.before["amount"]
    assert_equal "2026-11-01", log.before["period_start"]
  end

  test "修改、清除時預算已被刪除：回 not_found，不寫稽核" do
    budget = budget!(amount: 100)
    BeforeLock.hook = -> { Budget.where(id: budget.id).delete_all }
    patch "/api/budgets/#{budget.id}", params: { amount: 300 }, headers: @headers, as: :json
    assert_response :not_found
    assert_equal({ "error" => "not_found" }, response.parsed_body)

    budget = budget!(amount: 100)
    BeforeLock.hook = -> { Budget.where(id: budget.id).delete_all }
    delete "/api/budgets/#{budget.id}", headers: @headers
    assert_response :not_found
    assert_equal({ "error" => "not_found" }, response.parsed_body)

    assert_empty budget_logs
  end

  # ─── 套用基本預算 ─────────────────────────────

  test "套用：新增記 create、改金額記 update、清除記 delete，金額相同不寫，都帶來源" do
    added   = new_category("新增")
    changed = new_category("改金額")
    same    = new_category("金額相同")
    cleared = new_category("清除")
    { added => 100, changed => 200, same => 300 }.each do |category, amount|
      @company.budget_templates.create!(category: category, cycle: "month", amount: amount)
    end
    changed_budget = budget!(category: changed, amount: 999)
    budget!(category: same, amount: 300)
    cleared_budget = budget!(category: cleared, amount: 50)

    post "/api/budget-templates/apply", params: { cycle: "month", period_start: "2026-11-01", period_end: "2026-11-30" },
                                        headers: @headers, as: :json
    assert_response :success

    logs = budget_logs.to_a
    assert_equal %w[create delete update], logs.map(&:action).sort
    assert logs.all? { |log| log.actor == @admin }

    created = logs.find { |log| log.action == "create" }
    assert_equal [ "新增", 100.0, "budget_template" ], created.after.values_at("category_name", "amount", "via")

    updated = logs.find { |log| log.action == "update" }
    assert_equal changed_budget.id, updated.target_id
    assert_equal [ { "amount" => 999.0 }, { "amount" => 200.0, "via" => "budget_template" } ], [ updated.before, updated.after ]

    deleted = logs.find { |log| log.action == "delete" }
    assert_equal cleared_budget.id, deleted.target_id
    assert_nil deleted.after
    assert_equal [ "清除", 50.0, "budget_template" ], deleted.before.values_at("category_name", "amount", "via")
  end

  test "套用時鎖定預算再讀金額，查類別的次數不隨預算筆數增加" do
    seed_year_budgets(1)
    sql = capture_sql { apply_year }
    assert sql.any? { |q| q.include?(%(FROM "budgets")) && q.include?("FOR UPDATE") }
    few = category_queries(sql)
    seed_year_budgets(4)
    many = category_queries(capture_sql { apply_year })
    assert_equal few, many
    assert_equal 5, budget_logs.where(action: "delete").count
  end

  # ─── 類別停用、刪除連帶清除 ─────────────────────────────

  test "停用類別：當期與未來的預算每筆記 delete，過往與基本預算不寫" do
    @company.budget_templates.create!(category: @category, cycle: "month", amount: 100)
    budget!(period: Date.new(2026, 10, 1), amount: 10)
    current = budget!(amount: 20)
    future  = budget!(period: Date.new(2027, 1, 1), cycle: "year", amount: 30)

    patch "/api/categories/#{@category.id}/archive", headers: @headers
    assert_response :success

    logs = budget_logs.to_a
    assert_equal [ current.id, future.id ].sort, logs.map(&:target_id).sort
    logs.each do |log|
      assert_equal [ "delete", @admin, "category_clear" ], [ log.action, log.actor, log.before["via"] ]
      assert_nil log.after
    end
    assert_equal 0, AuditLog.where(company: @company).where.not(target_type: %w[budget category]).count
  end

  test "連帶清除時查類別的次數不隨預算筆數增加" do
    one = new_category("一筆")
    budget!(category: one, amount: 10)
    few = category_queries(capture_sql { patch "/api/categories/#{one.id}/archive", headers: @headers })

    three = new_category("三筆")
    [ Date.new(2026, 11, 1), Date.new(2026, 12, 1), Date.new(2027, 1, 1) ].each { |d| budget!(category: three, period: d, amount: 10) }
    many = category_queries(capture_sql { patch "/api/categories/#{three.id}/archive", headers: @headers })
    assert_response :success
    assert_equal few, many
  end

  test "刪除類別：連帶清除的預算記 delete；類別刪除失敗時一起回滾" do
    budget!(amount: 20)
    delete "/api/categories/#{@category.id}", headers: @headers
    assert_response :success
    assert_equal [ [ "delete", "category_clear" ] ], budget_logs.map { |log| [ log.action, log.before["via"] ] }

    other = new_category("被範本使用")
    budget!(category: other, amount: 20)
    create_recurring_template(company: @company, created_by: @admin, category: other)
    assert_no_difference -> { budget_logs.count } do
      delete "/api/categories/#{other.id}", headers: @headers
      assert_response :conflict
    end
  end

  # ─── 稽核日誌頁 ─────────────────────────────

  test "對象名稱：類別現在的名稱＋期間，月與年預算" do
    month = budget!(amount: 10)
    year  = budget!(period: Date.new(2026, 1, 1), cycle: "year", amount: 10)
    [ month, year ].each { |b| AuditLog.record!(b, action: "create", by: @admin, after: b.audit_snapshot) }
    @category.update!(name: "改名後")

    labels = list(target_type: "budget").to_h { |row| [ row["target_id"], row["target_label"] ] }
    assert_equal "改名後 2026/11 月預算", labels[month.id]
    assert_equal "改名後 2026 年預算", labels[year.id]
  end

  test "對象名稱：已刪除的預算從 delete 日誌取，類別仍顯示現在的名稱；類別永久刪除後用日誌內的名稱" do
    budget = budget!(amount: 10)
    delete "/api/budgets/#{budget.id}", headers: @headers
    @category.update!(name: "改名後")
    assert_equal [ "改名後 2026/11 月預算" ], list(target_type: "budget").map { |row| row["target_label"] }

    gone = new_category("已永久刪除")
    gone_budget = budget!(category: gone, amount: 10)
    delete "/api/budgets/#{gone_budget.id}", headers: @headers
    gone.destroy!
    row = list(target_type: "budget").find { |r| r["target_id"] == gone_budget.id }
    assert_equal "已永久刪除 2026/11 月預算", row["target_label"]
  end

  test "對象名稱的查詢數不隨預算筆數增加" do
    3.times { |i| budget!(category: new_category("a#{i}"), amount: 10).then { |b| delete "/api/budgets/#{b.id}", headers: @headers } }
    few = count_queries { list(target_type: "budget") }
    6.times { |i| budget!(category: new_category("b#{i}"), amount: 10).then { |b| delete "/api/budgets/#{b.id}", headers: @headers } }
    many = count_queries { list(target_type: "budget") }
    assert_equal few, many
  end

  test "列表的來源：delete 只在 before 帶來源也讀得到" do
    budget!(amount: 20)
    patch "/api/categories/#{@category.id}/archive", headers: @headers
    rows = list(target_type: "budget")
    assert_equal [ "category_clear" ], rows.map { |row| row["via"] }

    get "/api/audit-logs", params: { action: "delete", target_type: "budget" }, headers: @headers
    assert_equal 1, response.parsed_body["data"].size
  end

  test "公司隔離：他公司的預算名稱與日誌都查不到" do
    other_company = create_company(name: "他公司")
    other_admin   = create_user(company: other_company, role: "admin")
    other_category = other_company.categories.create!(kind: "expense", name: "他公司類別", account_code: "", sort_order: 99)
    other_budget = other_company.budgets.create!(category: other_category, cycle: "month", amount: 10,
      period_start: Date.new(2026, 11, 1), period_end: Date.new(2026, 11, 30))
    AuditLog.record!(other_budget, action: "delete", by: other_admin, before: other_budget.audit_snapshot)

    # 本公司日誌指向他公司預算 id：名稱查不到
    AuditLog.create!(company: @company, actor: @admin, target_type: "budget", target_id: other_budget.id, action: "update")
    rows = list(target_type: "budget")
    assert_equal 1, rows.size
    assert_nil rows.first["target_label"]

    patch "/api/budgets/#{other_budget.id}", params: { amount: 99 }, headers: @headers, as: :json
    assert_response :not_found
    delete "/api/budgets/#{other_budget.id}", headers: @headers
    assert_response :not_found
    assert_equal 10, other_budget.reload.amount
  end

  private

  def budget!(category: @category, cycle: "month", period: Date.new(2026, 11, 1), amount:)
    period_end = cycle == "year" ? period.end_of_year : period.end_of_month
    @company.budgets.create!(category: category, cycle: cycle, amount: amount, period_start: period, period_end: period_end)
  end

  def new_category(name)
    @company.categories.create!(kind: "expense", name: name, account_code: "", sort_order: 100 + @company.categories.count)
  end

  def budget_logs
    AuditLog.where(company: @company, target_type: "budget")
  end

  def list(**query)
    get "/api/audit-logs", params: query.merge(per_page: 100), headers: @headers
    assert_response :success
    response.parsed_body["data"]
  end

  # 每個類別各一筆年預算、沒有基本預算，套用時都會被清除（清除的稽核快照要取類別名稱）。
  def seed_year_budgets(count)
    count.times do |i|
      budget!(category: new_category("套用#{SecureRandom.hex(3)}#{i}"), cycle: "year", period: Date.new(2026, 1, 1), amount: 100)
    end
  end

  def apply_year
    post "/api/budget-templates/apply", params: { cycle: "year", period_start: "2026-01-01", period_end: "2026-12-31" },
                                        headers: @headers, as: :json
    assert_response :success
  end

  def category_queries(sql)
    sql.count { |q| q.match?(/FROM "categories"/) }
  end

  def capture_sql
    queries = []
    counter = ->(_, _, _, _, payload) { queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end

  def count_queries
    count = 0
    counter = ->(_, _, _, _, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end
