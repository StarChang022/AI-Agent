require "test_helper"
require "axlsx"

# 稽核日誌頁：列表、單筆與抽屜歷程 API（docs/資料模型.md §2.7）、對象名稱、類別與 Excel 匯入補寫稽核。
class AuditLogsPageTest < ActionDispatch::IntegrationTest
  # 讓指定金額的支出存檔失敗，用來驗證整批回滾。
  module FailingExpense
    mattr_accessor :amount, instance_accessor: false

    def save!(**)
      if FailingExpense.amount && amount == FailingExpense.amount
        errors.add(:amount, "測試失敗")
        raise ActiveRecord::RecordInvalid, self
      end
      super
    end
  end
  Expense.prepend(FailingExpense)
  Category.prepend(BeforeLock)

  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @account = create_account(company: @company, name: "主帳戶", opening_month: Date.new(2020, 1, 1))
    @other_company = create_company(name: "他公司")
    @other_admin   = create_user(company: @other_company, role: "admin")
    @tmpfiles = []
  end

  teardown do
    @tmpfiles.each(&:close!)
    BeforeLock.hook = nil
  end

  # ─── 權限與公司隔離 ─────────────────────────────

  test "員工查三支都是 403" do
    log = log_for(target: SecureRandom.uuid)
    get "/api/audit-logs", headers: auth_headers(@employee)
    assert_response :forbidden
    get "/api/audit-logs/history", params: { target_type: "expense", target_id: log.target_id }, headers: auth_headers(@employee)
    assert_response :forbidden
    get "/api/audit-logs/#{log.id}", headers: auth_headers(@employee)
    assert_response :forbidden
  end

  test "列表只有本公司" do
    mine   = log_for(target: SecureRandom.uuid)
    log_for(target: SecureRandom.uuid, company: @other_company, actor: @other_admin)
    assert_equal [ mine.id ], search.dig("data").map { |row| row["id"] }
  end

  test "單筆：他公司回 404、亂碼回 404" do
    other = log_for(target: SecureRandom.uuid, company: @other_company, actor: @other_admin)
    get "/api/audit-logs/#{other.id}", headers: auth_headers(@admin)
    assert_response :not_found
    get "/api/audit-logs/not-a-uuid", headers: auth_headers(@admin)
    assert_response :not_found
  end

  test "用他公司 actor_id 查不到" do
    log_for(target: SecureRandom.uuid, company: @other_company, actor: @other_admin)
    assert_empty search(actor_id: @other_admin.id)["data"]
    assert_empty search(actor_id: "not-a-uuid")["data"]
  end

  # ─── 篩選 ─────────────────────────────

  test "四個篩選與組合" do
    second = create_user(company: @company, role: "admin")
    expense_create = log_for(target: SecureRandom.uuid, type: "expense", action: "create", at: Time.zone.local(2026, 10, 1, 12))
    income_create  = log_for(target: SecureRandom.uuid, type: "income", action: "create", at: Time.zone.local(2026, 10, 2, 12))
    expense_delete = log_for(target: SecureRandom.uuid, type: "expense", action: "delete", at: Time.zone.local(2026, 10, 3, 12))
    by_second      = log_for(target: SecureRandom.uuid, type: "expense", action: "create", at: Time.zone.local(2026, 10, 4, 12), actor: second)

    assert_ids [ by_second, expense_delete, expense_create ], target_type: "expense"
    assert_ids [ by_second, income_create, expense_create ], action: "create"
    assert_ids [ by_second ], actor_id: second.id
    assert_ids [ expense_delete, income_create ], date_from: "2026-10-02", date_to: "2026-10-03"
    assert_ids [ expense_create ], target_type: "expense", action: "create", actor_id: @admin.id, date_to: "2026-10-03"
  end

  test "日期依台北時間整天計、兩端含當日" do
    before_day = log_for(target: SecureRandom.uuid, at: Time.zone.local(2026, 10, 18, 23, 59, 59))
    day_start  = log_for(target: SecureRandom.uuid, at: Time.zone.local(2026, 10, 19, 0, 0, 0))
    day_end    = log_for(target: SecureRandom.uuid, at: Time.zone.local(2026, 10, 19, 23, 59, 59))
    after_day  = log_for(target: SecureRandom.uuid, at: Time.zone.local(2026, 10, 20, 0, 0, 0))

    assert_ids [ day_end, day_start ], date_from: "2026-10-19", date_to: "2026-10-19"
    assert_ids [ day_end, day_start, before_day ], date_to: "2026-10-19"
    assert_ids [ after_day, day_end, day_start ], date_from: "2026-10-19"
  end

  test "不合法的條件回 422 且附訊息" do
    { target_type: "foo", action: "foo", date_from: "2026-13-01", date_to: "昨天" }.each do |key, value|
      get "/api/audit-logs", params: { key => value }, headers: auth_headers(@admin)
      assert_response :unprocessable_content, key.to_s
      assert response.parsed_body["message"].present?, key.to_s
    end
    assert_equal "INVALID_TARGET_TYPE", json_error(target_type: "foo")
    assert_equal "INVALID_ACTION",      json_error(action: "foo")
    assert_equal "INVALID_DATE",        json_error(date_from: "2026-13-01")
  end

  # ─── 排序與分頁 ─────────────────────────────

  test "排序：操作時間新到舊，同時間依 id 大到小" do
    at = Time.zone.local(2026, 10, 1, 12)
    same = 3.times.map { log_for(target: SecureRandom.uuid, at: at) }
    newest = log_for(target: SecureRandom.uuid, at: at + 1.hour)
    assert_equal [ newest.id ] + same.map(&:id).sort.reverse, search["data"].map { |row| row["id"] }
  end

  test "分頁：預設 10、上限 100" do
    11.times { log_for(target: SecureRandom.uuid) }
    body = search
    assert_equal 10, body["data"].size
    assert_equal({ "total" => 11, "page" => 1, "page_size" => 10 }, body["meta"])
    assert_equal 1, search(page: 2)["data"].size
    assert_equal 100, search(per_page: 500)["meta"]["page_size"]
  end

  test "分頁參數傳陣列或超大數字不會出錯" do
    log_for(target: SecureRandom.uuid)
    get "/api/audit-logs?page[]=2&per_page[]=1", headers: auth_headers(@admin)
    assert_response :success
    assert_equal({ "total" => 1, "page" => 1, "page_size" => 10 }, response.parsed_body["meta"])

    body = search(page: "999999999999999999999", per_page: "999999999999999999999")
    assert_empty body["data"]
    assert_equal 100_000, body["meta"]["page"]
    assert_equal 100, body["meta"]["page_size"]
  end

  # ─── 回傳欄位 ─────────────────────────────

  test "列表欄位：不回內容，via 與異動欄位正確" do
    target = SecureRandom.uuid
    log = log_for(target: target, type: "expense", action: "update",
                  before: { "planned_payout_date" => "2026-10-01" },
                  after: { "planned_payout_date" => "2026-10-02", "tax_id" => "1", "via" => "recurring" })
    row = search["data"].first
    assert_equal %w[action actor_name created_at id target_id target_label target_type via], row.keys.sort
    assert_equal log.id, row["id"]
    assert_equal @admin.name, row["actor_name"]
    assert_equal target, row["target_id"]
    assert_equal "recurring", row["via"]
  end

  test "via 從 before 取；沒有或內容不是物件時為 null" do
    log_for(target: SecureRandom.uuid, before: { "via" => "excel_import" }, at: 3.minutes.ago)
    log_for(target: SecureRandom.uuid, at: 2.minutes.ago)
    log_for(target: SecureRandom.uuid, before: [ 1, 2 ], after: "x", at: 1.minute.ago)
    assert_equal [ nil, nil, "excel_import" ], search["data"].map { |row| row["via"] }
  end

  test "列表不載入整份 before、after，永久刪除的名稱也只取需要的欄位" do
    expense = create_expense(vendor: "全聯")
    log_for(target: expense.id, type: "expense", action: "update",
            before: { "attachments" => [ "x" * 1000 ] }, after: { "attachments" => [] })
    AuditLog.record!(expense, action: "purge", by: @admin, before: expense.audit_snapshot)
    expense.delete

    rows = nil
    sql = capture_sql { rows = search["data"] }
    loads_content = sql.select { |q| q.match?(/"audit_logs"\.\*|"audit_logs"\."(before|after)"/) }
    assert_empty loads_content
    assert_equal [ "全聯" ], rows.map { |row| row["target_label"] }.uniq
  end

  test "單筆多回 before、after" do
    log = log_for(target: SecureRandom.uuid, before: { "a" => 1 }, after: { "a" => 2 })
    get "/api/audit-logs/#{log.id}", headers: auth_headers(@admin)
    assert_response :success
    body = response.parsed_body
    assert_equal({ "a" => 1 }, body["before"])
    assert_equal({ "a" => 2 }, body["after"])
    assert_not body.key?("changed_fields")
  end

  test "抽屜歷程走 /history：回陣列含內容，不會被單筆路由吃掉，只有本公司" do
    target = SecureRandom.uuid
    log_for(target: target, type: "expense", after: { "a" => 1 })
    log_for(target: target, type: "expense", company: @other_company, actor: @other_admin)
    get "/api/audit-logs/history", params: { target_type: "expense", target_id: target }, headers: auth_headers(@admin)
    assert_response :success
    rows = response.parsed_body
    assert_kind_of Array, rows
    assert_equal [ { "a" => 1 } ], rows.map { |row| row["after"] }

    get "/api/audit-logs/history", params: { target_type: "foo", target_id: target }, headers: auth_headers(@admin)
    assert_response :unprocessable_content
    assert_equal "INVALID_TARGET_TYPE", response.parsed_body["error"]
    get "/api/audit-logs/history", params: { target_type: "expense" }, headers: auth_headers(@admin)
    assert_response :unprocessable_content
    assert_equal "TARGET_ID_REQUIRED", response.parsed_body["error"]
  end

  # ─── 對象名稱 ─────────────────────────────

  test "各對象取名稱" do
    expense = create_expense(vendor: "全聯")
    income  = create_income(customer: "王小明")
    reimbursement = create_reimbursement(employee: @employee)
    other_account = create_account(company: @company, name: "現金")
    category = @company.categories.find_by!(kind: "expense", name: "交通費")
    template = create_recurring_template(company: @company, created_by: @admin, name: "房租")
    transfer = create_transfer(from: @account, to: other_account)

    assert_equal "全聯", label_of(expense)
    assert_equal "王小明", label_of(income)
    assert_equal @employee.name, label_of(reimbursement)
    assert_equal "現金", label_of(other_account)
    assert_equal "交通費", label_of(category)
    assert_equal "房租", label_of(template)
    assert_equal "主帳戶→現金", label_of(transfer)
  end

  test "空白時改用日期＋金額" do
    expense = create_expense(vendor: nil, amount: 12340, date: Date.new(2026, 10, 19))
    income  = create_income(customer: "暫時", amount: 500.6, date: Date.new(2026, 10, 19))
    income.update_columns(customer: "")
    assert_equal "2026/10/19 NT$ 12,340", label_of(expense)
    assert_equal "2026/10/19 NT$ 501", label_of(income)
  end

  test "垃圾桶內的紀錄照常取名稱" do
    expense = create_expense(vendor: "全聯")
    expense.update_columns(deleted_at: Time.current)
    assert_equal "全聯", label_of(expense)
  end

  test "改名後顯示現在的名稱" do
    account = create_account(company: @company, name: "舊名")
    log_for(target: account.id, type: "account")
    account.update!(name: "新名")
    assert_equal "新名", search["data"].first["target_label"]
  end

  test "永久刪除後從 purge 日誌取名稱" do
    expense = create_expense(vendor: "全聯")
    log_for(target: expense.id, type: "expense", action: "create")
    expense.update_columns(deleted_at: Time.current)
    delete "/api/expenses/#{expense.id}/purge", headers: auth_headers(@admin)
    assert_response :success
    assert_nil Expense.find_by(id: expense.id)

    assert_equal [ "全聯" ], search["data"].map { |row| row["target_label"] }.uniq
  end

  test "永久刪除的賣方空白時用 purge 內容的日期＋金額" do
    expense = create_expense(vendor: nil, amount: 12340, date: Date.new(2026, 10, 19))
    AuditLog.record!(expense, action: "purge", by: @admin, before: expense.audit_snapshot)
    expense.update_columns(deleted_at: Time.current)
    id = expense.id
    expense.delete
    assert_equal "2026/10/19 NT$ 12,340", search(target_type: "expense")["data"].find { |r| r["target_id"] == id }["target_label"]
  end

  test "永久刪除的資金移轉從日誌取「轉出→轉入」" do
    other = create_account(company: @company, name: "現金")
    transfer = create_transfer(from: @account, to: other)
    AuditLog.record!(transfer, action: "purge", by: @admin, before: transfer.audit_snapshot)
    transfer.delete
    assert_equal "主帳戶→現金", search(target_type: "transfer")["data"].first["target_label"]
  end

  test "都查不到回 null（紀錄不在、也沒有永久刪除日誌）" do
    log_for(target: SecureRandom.uuid, type: "expense")
    assert_nil search["data"].first["target_label"]
  end

  test "同一 id 不會取到他公司紀錄或 purge 日誌" do
    other_account = create_account(company: @other_company, name: "他公司帳戶")
    log_for(target: other_account.id, type: "account")
    AuditLog.create!(company: @other_company, actor: @other_admin, target_type: "account", target_id: other_account.id,
                     action: "purge", before: { name: "他公司帳戶" })
    assert_nil search["data"].first["target_label"]
  end

  test "一頁的查詢數不隨筆數增加" do
    3.times { |i| log_for(target: create_expense(vendor: "v#{i}").id, type: "expense") }
    few = count_queries { search }
    12.times { |i| log_for(target: create_expense(vendor: "w#{i}").id, type: "expense") }
    many = count_queries { search(per_page: 50) }
    assert_equal few, many
  end

  # ─── 類別補寫稽核 ─────────────────────────────

  test "新增類別寫 create" do
    post "/api/categories", params: { kind: "expense", name: "新類別", account_code: "6100" },
                            headers: auth_headers(@admin), as: :json
    assert_response :created
    log = category_logs(response.parsed_body["id"]).sole
    assert_equal "create", log.action
    assert_equal @admin, log.actor
    assert_equal "新類別", log.after["name"]
    assert_nil log.before
  end

  test "編輯類別只記有變更的欄位，沒變更不寫" do
    category = create_category
    patch "/api/categories/#{category.id}", params: { name: "改名" }, headers: auth_headers(@admin), as: :json
    assert_response :success
    log = category_logs(category.id).sole
    assert_equal "update", log.action
    assert_equal({ "name" => "原名" }, log.before)
    assert_equal({ "name" => "改名" }, log.after)

    patch "/api/categories/#{category.id}", params: { name: "改名" }, headers: auth_headers(@admin), as: :json
    assert_response :success
    assert_equal 1, category_logs(category.id).count
  end

  test "停用、啟用都寫 update，重複送出不多寫" do
    category = create_category
    patch "/api/categories/#{category.id}/archive", headers: auth_headers(@admin)
    assert_response :success
    patch "/api/categories/#{category.id}/archive", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "ALREADY_ARCHIVED", response.parsed_body["error"]
    log = category_logs(category.id).sole
    assert_equal [ "update", { "is_archived" => false }, { "is_archived" => true } ], [ log.action, log.before, log.after ]

    patch "/api/categories/#{category.id}/unarchive", headers: auth_headers(@admin)
    assert_response :success
    patch "/api/categories/#{category.id}/unarchive", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "NOT_ARCHIVED", response.parsed_body["error"]
    logs = category_logs(category.id).order(:created_at).to_a
    assert_equal 2, logs.size
    assert_equal({ "is_archived" => false }, logs.last.after)
  end

  test "排序不寫" do
    categories = 2.times.map { |i| create_category(name: "排序#{i}") }
    patch "/api/categories/reorder", params: { ids: categories.reverse.map(&:id) }, headers: auth_headers(@admin), as: :json
    assert_response :success
    assert_equal 0, AuditLog.where(company: @company, target_type: "category").count
  end

  test "編輯類別鎖定後才確認狀態：期間被停用回 409、被刪除回 404，都不寫稽核" do
    category = create_category
    BeforeLock.hook = -> { Category.find(category.id).update_columns(is_archived: true) }
    patch "/api/categories/#{category.id}", params: { name: "改名" }, headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert_equal "CATEGORY_ARCHIVED", response.parsed_body["error"]

    category.update_columns(is_archived: false)
    BeforeLock.hook = -> { Category.find(category.id).update_columns(deleted_at: Time.current) }
    patch "/api/categories/#{category.id}", params: { name: "改名" }, headers: auth_headers(@admin), as: :json
    assert_response :not_found

    assert_equal "原名", category.reload.name
    assert_empty category_logs(category.id)
  end

  test "同時改名：後到的稽核 before 是先完成的名稱" do
    category = create_category
    BeforeLock.hook = -> { Category.find(category.id).update_columns(name: "先改") }
    patch "/api/categories/#{category.id}", params: { name: "後改" }, headers: auth_headers(@admin), as: :json
    assert_response :success
    log = category_logs(category.id).sole
    assert_equal [ { "name" => "先改" }, { "name" => "後改" } ], [ log.before, log.after ]
  end

  test "停用、啟用鎖定後發現已被刪除回 404，不改狀態也不寫稽核" do
    category = create_category
    BeforeLock.hook = -> { Category.find(category.id).update_columns(deleted_at: Time.current) }
    patch "/api/categories/#{category.id}/archive", headers: auth_headers(@admin)
    assert_response :not_found
    assert_not category.reload.is_archived

    archived = create_category(name: "停用中")
    archived.update_columns(is_archived: true)
    BeforeLock.hook = -> { Category.find(archived.id).update_columns(deleted_at: Time.current) }
    patch "/api/categories/#{archived.id}/unarchive", headers: auth_headers(@admin)
    assert_response :not_found
    assert archived.reload.is_archived

    assert_equal 0, AuditLog.where(company: @company, target_type: "category").count
  end

  # ─── Excel 匯入 ─────────────────────────────

  test "Excel 匯入新增類別：寫 create 且帶來源，操作人為匯入者" do
    assert_difference -> { @company.categories.count }, 1 do
      post_import([ receipt("類別" => "匯入新類別") ])
    end
    category = @company.categories.find_by!(name: "匯入新類別")
    log = category_logs(category.id).sole
    assert_equal "create", log.action
    assert_equal @admin, log.actor
    assert_equal "excel_import", log.after["via"]
  end

  test "Excel 匯入重新啟用類別：寫 update 且帶來源" do
    category = create_category(name: "老類別")
    category.update!(is_archived: true)
    post_import([ receipt("類別" => "老類別") ], category_mapping: { "老類別" => "reactivate" })
    assert_not category.reload.is_archived
    log = category_logs(category.id).sole
    assert_equal "update", log.action
    assert_equal @admin, log.actor
    assert_equal "excel_import", log.after["via"]
    assert_equal({ "is_archived" => true }, log.before)
  end

  test "Excel 匯入失敗時類別與稽核一起回滾" do
    FailingExpense.amount = 13
    assert_no_difference [ -> { AuditLog.where(target_type: "category").count }, -> { @company.categories.count } ] do
      post_import([ receipt("類別" => "會回滾"), receipt("廠商" => "乙", "含稅金額" => 13) ], expect: :unprocessable_content)
    end
    assert_equal "IMPORT_FAILED", response.parsed_body["error"]
  ensure
    FailingExpense.amount = nil
  end

  private

  def log_for(target:, type: "expense", action: "create", company: @company, actor: @admin, at: nil, before: nil, after: nil)
    attrs = { company: company, actor: actor, target_type: type, target_id: target, action: action, before: before, after: after }
    attrs[:created_at] = at if at
    AuditLog.create!(attrs)
  end

  def search(**query)
    get "/api/audit-logs", params: query, headers: auth_headers(@admin)
    assert_response :success
    response.parsed_body
  end

  def json_error(**query)
    get "/api/audit-logs", params: query, headers: auth_headers(@admin)
    response.parsed_body["error"]
  end

  def assert_ids(expected, **query)
    assert_equal expected.map(&:id), search(**query)["data"].map { |row| row["id"] }, query.inspect
  end

  def label_of(record)
    type = record.class.model_name.element
    log = log_for(target: record.id, type: type)
    get "/api/audit-logs/#{log.id}", headers: auth_headers(@admin)
    single = response.parsed_body["target_label"]
    listed = search(target_type: type)["data"].find { |row| row["target_id"] == record.id }["target_label"]
    assert_equal single, listed
    listed
  end

  def expense_category
    @company.categories.find_by!(kind: "expense", name: "交通費")
  end

  def create_category(name: "原名")
    @company.categories.create!(kind: "expense", name: name, account_code: "", sort_order: 100 + @company.categories.count)
  end

  def create_expense(vendor:, amount: 9, date: Date.current)
    @company.expenses.create!(account: @account, source: "general", created_by: @admin, category: expense_category,
      document_type: "receipt", tax_rate: "exempt_0", vendor: vendor, amount: amount, date: date)
  end

  def create_income(customer:, amount: 9, date: Date.current)
    @company.incomes.create!(account: @account, created_by: @admin, category: @company.categories.of_kind("income").first,
      document_type: "receipt", tax_rate: "exempt_0", customer: customer, amount: amount, date: date)
  end

  def create_transfer(from:, to:)
    post "/api/transfers", params: { from_account_id: from.id, to_account_id: to.id, amount: 100, transfer_date: Date.current },
                           headers: auth_headers(@admin), as: :json
    assert_response :created
    @company.transfers.find(response.parsed_body["id"])
  end

  def category_logs(id)
    AuditLog.where(company: @company, target_type: "category", target_id: id)
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

  HEADERS = ExcelImport::Schema::EXPENSE.fields.map(&:header)
  RECEIPT = { "發生日期" => "2026/10/1", "文件類型" => "收據", "廠商" => "甲", "類別" => "交通費", "帳戶" => "主帳戶", "含稅金額" => 100 }.freeze

  def receipt(overrides = {})
    RECEIPT.merge(overrides)
  end

  def post_import(rows, category_mapping: nil, expect: :success)
    params = { file: xlsx(rows.map { |row| HEADERS.map { |h| row[h] } }) }
    params[:category_mapping] = category_mapping.to_json if category_mapping
    post "/api/expenses/import", headers: auth_headers(@admin), params: params
    assert_response expect
  end

  def xlsx(rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "資料") do |sheet|
      sheet.add_row HEADERS
      rows.each { |row| sheet.add_row row }
    end
    file = Tempfile.new([ "import", ".xlsx" ])
    @tmpfiles << file
    file.binmode
    file.write(package.to_stream.read)
    file.flush
    Rack::Test::UploadedFile.new(file.path, Mime[:xlsx].to_s, true, original_filename: "import.xlsx")
  end
end
