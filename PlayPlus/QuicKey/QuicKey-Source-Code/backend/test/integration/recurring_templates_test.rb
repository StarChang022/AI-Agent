require "test_helper"

# 固定收支範本 API（PRD 第 17 條）：驗證、補齊、編輯規則、垃圾桶、稽核、權限、公司隔離。
class RecurringTemplatesTest < ActionDispatch::IntegrationTest
  RecurringTemplate.prepend(BeforeLock)

  setup do
    travel_to Time.zone.local(2026, 11, 11, 12)
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @category = @company.categories.of_kind("expense").active.first
    @account  = account_for(@company)
  end

  def body(overrides = {})
    {
      direction: "expense", name: "辦公室租金", category_id: @category.id, account_id: @account.id,
      document_type: "receipt", tax_rate: "exempt_0", counterparty: "大樓管理公司", amount: "21000",
      frequency: "monthly", day_of_month: 5, start_month: "2026-11"
    }.merge(overrides)
  end

  def post_template(overrides = {})
    post "/api/recurring-templates", params: body(overrides), headers: auth_headers(@admin), as: :json
  end

  def patch_template(template, attrs)
    patch "/api/recurring-templates/#{template.id}", params: attrs, headers: auth_headers(@admin), as: :json
  end

  def template(**attrs)
    create_recurring_template(company: @company, created_by: @admin, **attrs)
  end

  # 建立時補齊到今天，已產生過紀錄的範本。
  def generated_template(**attrs)
    template(**attrs).tap { |t| RecurringGenerator.call(t, today: Date.current) }
  end

  def run_job
    GenerateRecurringRecordsJob.perform_now
  end

  def assert_error(code, status)
    assert_response status
    assert_equal code, response.parsed_body["error"]
    assert response.parsed_body["message"].present?
  end

  test "建立範本，寫稽核；週期日未到不產生" do
    post_template(day_of_month: 20)
    assert_response :created

    res = response.parsed_body
    assert_equal "active", res["status"]
    assert_equal 0, res["backfilled_count"]
    assert_equal "2026-11", res["next_period"]
    assert_equal "2026-11-20", res["next_date"]
    assert_not res["start_month_locked"]

    log = AuditLog.where(target_type: "recurring_template", target_id: res["id"]).sole
    assert_equal "create", log.action
    assert_equal "辦公室租金", log.after["name"]
  end

  test "建立當天剛好是週期日，當期算已過" do
    post_template(day_of_month: 11)

    res = response.parsed_body
    assert_equal 1, res["backfilled_count"]
    assert_equal "2026-11", res["last_generated_period"]
    assert_equal 1, res["generated_count"]
    assert res["start_month_locked"]
  end

  test "開始月份在過去時補齊，一律待付款，預計付款日以建立當天為登錄日" do
    @company.update!(payout_day: 25)
    post_template(start_month: "2026-08")

    res = response.parsed_body
    assert_equal 4, res["backfilled_count"]
    expenses = Expense.where(recurring_template_id: res["id"]).order(:date)
    assert_equal %w[2026-08 2026-09 2026-10 2026-11], expenses.pluck(:recurring_period)
    assert_equal [ "pending" ], expenses.pluck(:payout_status).uniq
    assert_equal [ Date.new(2026, 11, 25) ], expenses.pluck(:planned_payout_date).uniq
    assert_equal Date.new(2026, 8, 5), expenses.first.date
  end

  test "欄位驗證" do
    {
      { name: " " } => "INVALID_NAME",
      { name: "x" * 51 } => "INVALID_NAME",
      { counterparty: "" } => "INVALID_COUNTERPARTY",
      { direction: "x" } => "INVALID_DIRECTION",
      { category_id: SecureRandom.uuid } => "CATEGORY_NOT_FOUND",
      { account_id: "" } => "ACCOUNT_REQUIRED",
      { account_id: SecureRandom.uuid } => "ACCOUNT_NOT_FOUND",
      { document_type: "x" } => "INVALID_DOCUMENT_TYPE",
      { document_type: "invoice", tax_rate: "x" } => "INVALID_TAX_RATE",
      { document_type: "invoice", tax_id: "" } => "TAX_ID_REQUIRED",
      { tax_id: "123" } => "INVALID_TAX_ID",
      { amount: "0" } => "INVALID_AMOUNT",
      { amount: "abc" } => "INVALID_AMOUNT",
      { amount: "1.234" } => "INVALID_AMOUNT",
      { amount: "10000000000" } => "INVALID_AMOUNT",
      { frequency: "weekly" } => "INVALID_SCHEDULE",
      { day_of_month: 32 } => "INVALID_SCHEDULE",
      { frequency: "yearly", month_of_year: 13 } => "INVALID_SCHEDULE",
      { start_month: "2026-13" } => "INVALID_MONTH",
      { start_month: "1999-12" } => "INVALID_MONTH",
      { end_month: "2026-10" } => "INVALID_MONTH"
    }.each do |attrs, code|
      post_template(attrs)
      assert_error code, :unprocessable_content
    end
    assert_empty @company.recurring_templates
  end

  test "類別的類型要和收支方向相同；已停用或在垃圾桶的類別不可選" do
    post_template(direction: "income")
    assert_error "CATEGORY_WRONG_KIND", :unprocessable_content

    archived = @company.categories.of_kind("expense").active.second
    archived.update!(is_archived: true)
    post_template(category_id: archived.id)
    assert_error "CATEGORY_NOT_FOUND", :unprocessable_content

    trashed = @company.categories.of_kind("expense").active.first
    trashed.discard!
    post_template(category_id: trashed.id)
    assert_error "CATEGORY_NOT_FOUND", :unprocessable_content
  end

  test "開始到結束月份之間沒有任何一期時不可建立" do
    post_template(frequency: "yearly", month_of_year: 3, start_month: "2026-04", end_month: "2026-12")
    assert_error "NO_PERIODS", :unprocessable_content
  end

  test "預覽：只查不寫，回補產生筆數與下一期" do
    post "/api/recurring-templates/preview", params: { frequency: "monthly", day_of_month: 5, start_month: "2026-09" },
      headers: auth_headers(@admin), as: :json
    assert_response :ok

    res = response.parsed_body
    assert_equal 3, res["backfill_count"]
    assert_equal %w[2026-09 2026-10 2026-11], res["backfill_periods"]
    assert_equal "2026-12", res["next_period"]
    assert_equal "2026-12-05", res["next_date"]
    assert res["has_periods"]
    assert_empty @company.recurring_templates
  end

  test "預覽：一期都沒有時回原因；週期不合法回 422" do
    post "/api/recurring-templates/preview",
      params: { frequency: "yearly", month_of_year: 3, day_of_month: 1, start_month: "2026-04", end_month: "2026-12" },
      headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_not response.parsed_body["has_periods"]
    assert_equal 0, response.parsed_body["backfill_count"]
    assert response.parsed_body["message"].present?

    post "/api/recurring-templates/preview", params: { frequency: "x" }, headers: auth_headers(@admin), as: :json
    assert_error "INVALID_SCHEDULE", :unprocessable_content
  end

  # 先預覽再用同樣的值儲存，兩邊筆數要一致。
  def assert_preview_matches_patch(t, attrs, count:, next_period:)
    saved  = t.reload.attributes
    before = t.expenses.pluck(:recurring_period)
    post "/api/recurring-templates/preview", params: attrs.merge(template_id: t.id),
      headers: auth_headers(@admin), as: :json
    assert_response :ok
    res = response.parsed_body
    assert_equal count, res["backfill_count"]
    assert_equal next_period, res["next_period"]
    assert_equal saved, t.reload.attributes
    assert_equal before, t.expenses.pluck(:recurring_period)

    patch_template(t, attrs)
    assert_response :ok
    assert_equal count, response.parsed_body["backfilled_count"].to_i
    assert_equal next_period, response.parsed_body["next_period"]
    assert_equal res["backfill_periods"], (t.expenses.pluck(:recurring_period) - before).sort
  end

  test "編輯預覽與儲存一致：改週期日" do
    travel_to Date.new(2026, 11, 2).noon
    t = generated_template(day_of_month: 5, start_month: "2026-10")

    assert_preview_matches_patch(t, { day_of_month: 1 }, count: 1, next_period: "2026-12")
  end

  test "編輯預覽與儲存一致：週期日還沒到" do
    travel_to Date.new(2026, 11, 2).noon
    t = generated_template(day_of_month: 5, start_month: "2026-10")

    assert_preview_matches_patch(t, { day_of_month: 3 }, count: 0, next_period: "2026-11")
  end

  test "編輯預覽與儲存一致：每年改每月，已過的期數不補" do
    travel_to Date.new(2026, 3, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2026-03")

    travel_to Date.new(2026, 11, 11).noon
    assert_preview_matches_patch(t, { frequency: "monthly", day_of_month: 5 }, count: 1, next_period: "2026-12")
    assert_equal %w[2026-03 2026-11], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "編輯預覽與儲存一致：每年週期改月份，同一年只一筆" do
    travel_to Date.new(2026, 3, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2026-03")

    travel_to Date.new(2026, 11, 11).noon
    assert_preview_matches_patch(t, { month_of_year: 11, day_of_month: 5 }, count: 0, next_period: "2027-11")
  end

  test "編輯預覽與儲存一致：歷史範本回到進行中，中間的期數不補" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")

    travel_to Date.new(2026, 11, 11).noon
    assert_preview_matches_patch(t, { end_month: "2027-06" }, count: 1, next_period: "2026-12")
  end

  test "編輯預覽與儲存一致：開始月份改到過去，比照建立補齊" do
    t = template(start_month: "2026-12")

    assert_preview_matches_patch(t, { start_month: "2026-09" }, count: 3, next_period: "2026-12")
  end

  test "編輯預覽與儲存一致：還沒產生過的範本改週期，比照建立補齊" do
    t = template(frequency: "yearly", month_of_year: 12, day_of_month: 15, start_month: "2026-09")

    assert_preview_matches_patch(t, { frequency: "monthly", day_of_month: 5 }, count: 3, next_period: "2026-12")
  end

  test "編輯預覽與儲存一致：結束月份早於已產生的期數，不算沒有下一期" do
    t = generated_template(start_month: "2026-09")

    post "/api/recurring-templates/preview", params: { template_id: t.id, end_month: "2026-09" },
      headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert response.parsed_body["has_periods"]
    assert_equal 0, response.parsed_body["backfill_count"]
    assert_nil response.parsed_body["next_period"]
  end

  test "編輯預覽：類別被擋時回和儲存相同的錯誤，同一次換成可用的類別就不擋" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")
    travel_to Date.new(2026, 11, 11).noon
    t.category.update!(is_archived: true)
    other = @company.categories.of_kind("expense").active.first

    post "/api/recurring-templates/preview", params: { template_id: t.id, end_month: "2027-06" },
      headers: auth_headers(@admin), as: :json
    assert_error "CATEGORY_ARCHIVED", :conflict

    post "/api/recurring-templates/preview", params: { template_id: t.id, end_month: "2027-06", category_id: other.id },
      headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal 1, response.parsed_body["backfill_count"]
  end

  test "編輯預覽：開始月份鎖定回 409；別家公司或垃圾桶內的範本回 404；只查不寫" do
    t = generated_template(start_month: "2026-09")
    post "/api/recurring-templates/preview", params: { template_id: t.id, start_month: "2026-01" },
      headers: auth_headers(@admin), as: :json
    assert_error "START_MONTH_LOCKED", :conflict

    other = create_company(name: "別家公司")
    foreign = create_recurring_template(company: other, created_by: create_user(company: other, role: "admin"))
    t.discard!
    [ foreign, t ].each do |record|
      post "/api/recurring-templates/preview", params: { template_id: record.id, day_of_month: 1 },
        headers: auth_headers(@admin), as: :json
      assert_response :not_found
    end
  end

  test "列表依方向與分頁分開，meta 回全部分頁的數量" do
    income_category = @company.categories.of_kind("income").active.first
    active  = template(day_of_month: 20)
    history = template(start_month: "2026-01", end_month: "2026-02", last_generated_period: "2026-02")
    trashed = template(day_of_month: 21)
    trashed.discard!
    template(direction: "income", category: income_category, day_of_month: 22)

    get "/api/recurring-templates", params: { direction: "expense" }, headers: auth_headers(@admin)
    res = response.parsed_body
    assert_equal [ active.id ], res["data"].map { |t| t["id"] }
    assert_equal({ "active" => 1, "history" => 1, "trash" => 1 }, res["meta"]["counts"]["expense"])
    assert_equal({ "active" => 1, "history" => 0, "trash" => 0 }, res["meta"]["counts"]["income"])

    get "/api/recurring-templates", params: { direction: "expense", tab: "history" }, headers: auth_headers(@admin)
    assert_equal [ history.id ], response.parsed_body["data"].map { |t| t["id"] }

    get "/api/recurring-templates", params: { direction: "expense", tab: "trash" }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].sole
    assert_equal trashed.id, row["id"]
    assert_equal "trash", row["status"]
    assert_nil row["next_period"]

    get "/api/recurring-templates", params: { direction: "x" }, headers: auth_headers(@admin)
    assert_error "INVALID_DIRECTION", :unprocessable_content
  end

  test "列表分頁" do
    3.times { |i| template(name: "範本#{i}", day_of_month: 20) }

    get "/api/recurring-templates", params: { direction: "expense", per_page: 2, page: 2 }, headers: auth_headers(@admin)

    assert_equal 1, response.parsed_body["data"].size
    assert_equal 3, response.parsed_body["meta"]["total"]
  end

  test "範本明細的紀錄不含垃圾桶，依期數新到舊" do
    t = generated_template(start_month: "2026-09")
    t.expenses.find_by(recurring_period: "2026-10").discard!

    get "/api/recurring-templates/#{t.id}/records", headers: auth_headers(@admin)

    res = response.parsed_body
    assert_equal %w[2026-11 2026-09], res["data"].map { |r| r["recurring_period"] }
    assert_equal 2, res["meta"]["total"]
    assert_equal "expense", res["data"].first["kind"]
    assert_equal "pending", res["data"].first["status"]

    get "/api/recurring-templates/#{t.id}", headers: auth_headers(@admin)
    assert_equal 2, response.parsed_body["generated_count"]
  end

  test "編輯只影響尚未產生的期數，寫稽核" do
    t = generated_template(start_month: "2026-11")
    patch_template(t, amount: "30000", name: "新名稱")
    assert_response :ok

    assert_equal BigDecimal("1000"), t.expenses.sole.amount
    log = AuditLog.where(target_type: "recurring_template", target_id: t.id, action: "update").sole
    assert_equal "辦公室租金", log.before["name"]
    assert_equal "新名稱", log.after["name"]

    travel_to Date.new(2026, 12, 5).noon
    run_job
    assert_equal BigDecimal("30000"), t.expenses.find_by(recurring_period: "2026-12").amount
  end

  test "已產生過紀錄不可改開始月份，紀錄全刪了也一樣" do
    t = generated_template(start_month: "2026-11")
    t.expenses.sole.discard!

    patch_template(t, start_month: "2026-10")
    assert_error "START_MONTH_LOCKED", :conflict

    get "/api/recurring-templates/#{t.id}", headers: auth_headers(@admin)
    assert response.parsed_body["start_month_locked"]
    assert_equal 0, response.parsed_body["generated_count"]
  end

  test "還沒產生過紀錄時可改開始月份，改到過去比照建立補齊" do
    t = template(day_of_month: 20)

    patch_template(t, start_month: "2026-09")

    assert_response :ok
    assert_equal 2, response.parsed_body["backfilled_count"]
    assert_equal %w[2026-09 2026-10], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "方向不可改，帶了也忽略" do
    t = template(day_of_month: 20)
    patch_template(t, direction: "income")

    assert_response :ok
    assert_equal "expense", t.reload.direction
  end

  test "結束月份不可早於開始月份，可以早於已產生的期數，範本變歷史，紀錄不受影響" do
    t = generated_template(start_month: "2026-09")

    patch_template(t, end_month: "2026-08")
    assert_error "INVALID_MONTH", :unprocessable_content

    patch_template(t, end_month: "2026-09")
    assert_response :ok
    assert_equal "history", response.parsed_body["status"]
    assert_equal 3, t.expenses.count
  end

  test "週期日改到已過：儲存當下產生當期一筆，再存一次不重複" do
    travel_to Date.new(2026, 11, 2).noon
    t = generated_template(day_of_month: 5, start_month: "2026-10")
    assert_equal "2026-10", t.reload.last_generated_period

    patch_template(t, day_of_month: 1)
    assert_response :ok
    assert_equal 1, response.parsed_body["backfilled_count"]
    assert_equal "2026-12", response.parsed_body["next_period"]
    assert_equal Date.new(2026, 11, 1), t.expenses.find_by(recurring_period: "2026-11").date

    patch_template(t, day_of_month: 1)
    assert_response :ok
    assert_nil response.parsed_body["backfilled_count"]

    patch_template(t, day_of_month: 2)
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal 2, t.expenses.count
  end

  test "週期日改了但還沒到：不產生，到了才產生" do
    travel_to Date.new(2026, 11, 2).noon
    t = generated_template(day_of_month: 5, start_month: "2026-10")

    patch_template(t, day_of_month: 3)
    assert_response :ok
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal "2026-11-03", response.parsed_body["next_date"]
    assert_equal 1, t.expenses.count
  end

  test "當期已產生，改週期日不重複" do
    t = generated_template(day_of_month: 5, start_month: "2026-11")

    patch_template(t, day_of_month: 1)

    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal %w[2026-11], t.expenses.pluck(:recurring_period)
  end

  test "只改名稱不產生，週期日已過的留給每日檢查" do
    t = generated_template(day_of_month: 5, start_month: "2026-10")
    t.update_columns(last_generated_period: "2026-09")

    assert_no_difference -> { t.expenses.count } do
      patch_template(t, name: "改名")
    end
    assert_nil response.parsed_body["backfilled_count"]
  end

  test "週期日改晚，本月已產生：下一期是下個月" do
    t = generated_template(day_of_month: 5, start_month: "2026-11")

    patch_template(t, day_of_month: 25)
    run_job

    assert_equal "2026-12", t.reload.next_period
    assert_equal 1, t.expenses.count
  end

  test "每年改每月：已過的期數不補，從當期開始" do
    travel_to Date.new(2026, 3, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2026-03")
    assert_equal "2026-03", t.reload.last_generated_period

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, frequency: "monthly", day_of_month: 5)
    assert_response :ok
    assert_equal 1, response.parsed_body["backfilled_count"]
    assert_equal %w[2026-03 2026-11], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "每月改每年：不受同一年限制，當年的週期月份照常產生" do
    t = generated_template(day_of_month: 20, start_month: "2026-10")
    assert_equal "2026-10", t.reload.last_generated_period

    patch_template(t, frequency: "yearly", month_of_year: 12, day_of_month: 15)
    assert_response :ok
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal "2026-12", response.parsed_body["next_period"]

    travel_to Date.new(2026, 12, 15).noon
    run_job
    assert_equal Date.new(2026, 12, 15), t.expenses.find_by(recurring_period: "2026-12").date
  end

  test "每月改每年：週期月份已過就是明年" do
    t = generated_template(day_of_month: 20, start_month: "2026-10")

    patch_template(t, frequency: "yearly", month_of_year: 3, day_of_month: 15)

    assert_equal "2027-03", response.parsed_body["next_period"]
  end

  test "每年週期改月份：同一年只一筆" do
    travel_to Date.new(2026, 3, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2026-03")

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, month_of_year: 12)

    assert_equal "2027-12", response.parsed_body["next_period"]
    travel_to Date.new(2026, 12, 20).noon
    run_job
    assert_equal 1, t.expenses.count
  end

  test "每年週期改到當月：今年還沒產生、週期日已過，儲存當下產生" do
    travel_to Date.new(2025, 12, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 12, day_of_month: 15, start_month: "2025-12")

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, month_of_year: 11, day_of_month: 5)

    assert_equal 1, response.parsed_body["backfilled_count"]
    assert_equal %w[2025-12 2026-11], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "歷史範本延後結束月份：中間的期數不補，當期週期日已過立即產生一筆" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")
    assert_equal "history", t.reload.status

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, end_month: "2027-06")

    assert_response :ok
    res = response.parsed_body
    assert_equal "active", res["status"]
    assert_equal 1, res["backfilled_count"]
    assert_equal "2026-12", res["next_period"]
    assert_equal %w[2026-06 2026-11], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "歷史範本延後結束月份：當期週期日未到，到了才產生" do
    travel_to Date.new(2026, 6, 25).noon
    t = generated_template(day_of_month: 20, start_month: "2026-06", end_month: "2026-06")

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, end_month: nil)
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal "2026-11", response.parsed_body["next_period"]
  end

  test "歷史範本延後後仍沒有下一期：留在歷史，不產生" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, end_month: "2026-09")

    assert_equal "history", response.parsed_body["status"]
    assert_equal 1, t.expenses.count
  end

  test "每年週期的歷史範本延後：今天不在週期月份就從下一個週期月份開始" do
    travel_to Date.new(2025, 3, 20).noon
    t = generated_template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2025-03", end_month: "2025-12")

    travel_to Date.new(2026, 11, 11).noon
    patch_template(t, end_month: nil)

    assert_equal "2027-03", response.parsed_body["next_period"]
    assert_equal 1, t.expenses.count
  end

  test "類別在垃圾桶或已停用時不可延後結束月份" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")
    travel_to Date.new(2026, 11, 11).noon

    t.category.update!(is_archived: true)
    patch_template(t, end_month: "2027-06")
    assert_error "CATEGORY_ARCHIVED", :conflict

    t.category.update!(is_archived: false, deleted_at: Time.current)
    patch_template(t, end_month: "2027-06")
    assert_error "CATEGORY_IN_TRASH", :conflict
    assert_equal "2026-06", t.reload.end_month
  end

  test "歷史範本類別在垃圾桶時，其他欄位仍可編輯" do
    travel_to Date.new(2026, 6, 10).noon
    t = generated_template(start_month: "2026-06", end_month: "2026-06")
    t.category.discard!

    patch_template(t, name: "改名")

    assert_response :ok
    assert_equal "改名", t.reload.name
  end

  test "刪除任何時候都可以，已產生的紀錄不受影響，寫稽核；垃圾桶內不可編輯" do
    t = generated_template(start_month: "2026-11")

    delete "/api/recurring-templates/#{t.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert t.reload.discarded?
    assert_equal 1, t.expenses.kept.count
    assert_equal "delete", AuditLog.where(target_type: "recurring_template", target_id: t.id).order(:created_at).last.action

    patch_template(t, name: "x")
    assert_response :not_found
  end

  test "還原：不補垃圾桶期間的期數，當期週期日已過立即產生一筆，操作人仍是範本建立者" do
    travel_to Date.new(2026, 8, 10).noon
    t = generated_template(start_month: "2026-08")
    t.discard!

    other = create_user(company: @company, role: "admin")
    travel_to Date.new(2026, 11, 11).noon
    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(other), as: :json

    assert_response :ok
    assert_equal 1, response.parsed_body["backfilled_count"]
    assert_equal "2026-12", response.parsed_body["next_period"]
    assert_equal %w[2026-08 2026-11], t.expenses.order(:date).pluck(:recurring_period)

    record = t.expenses.find_by(recurring_period: "2026-11")
    assert_equal @admin.id, record.created_by_id
    assert_equal other.id, AuditLog.where(target_type: "recurring_template", target_id: t.id, action: "restore").sole.actor_user_id
  end

  test "還原：當期週期日未到，到了才產生" do
    travel_to Date.new(2026, 8, 10).noon
    t = generated_template(day_of_month: 5, start_month: "2026-08")
    t.update!(day_of_month: 20)
    t.discard!

    travel_to Date.new(2026, 11, 11).noon
    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json
    assert_equal 0, response.parsed_body["backfilled_count"]

    travel_to Date.new(2026, 11, 20).noon
    run_job
    assert_equal %w[2026-08 2026-11], t.expenses.order(:date).pluck(:recurring_period)
  end

  test "每年週期還原：週期月份落在垃圾桶期間不補，下一期是明年" do
    travel_to Date.new(2026, 2, 1).noon
    t = template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2026-01")
    t.discard!

    travel_to Date.new(2026, 11, 11).noon
    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_equal "2027-03", response.parsed_body["next_period"]
    assert_empty t.expenses
  end

  test "每年週期還原：今天就在週期月份且週期日已過，立即產生" do
    travel_to Date.new(2026, 2, 1).noon
    t = template(frequency: "yearly", month_of_year: 11, day_of_month: 5, start_month: "2026-01")
    t.discard!

    travel_to Date.new(2026, 11, 11).noon
    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json

    assert_equal 1, response.parsed_body["backfilled_count"]
    assert_equal [ "2026-11" ], t.expenses.pluck(:recurring_period)
  end

  test "類別在垃圾桶或已停用時不可還原，歷史範本也一樣" do
    t = generated_template(start_month: "2026-11", end_month: "2026-11")
    t.discard!

    t.category.discard!
    get "/api/recurring-templates/#{t.id}", headers: auth_headers(@admin)
    assert_not response.parsed_body["restorable"]
    assert response.parsed_body["category"]["deleted_at"].present?

    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json
    assert_error "CATEGORY_IN_TRASH", :conflict

    t.category.update!(deleted_at: nil, is_archived: true)
    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json
    assert_error "CATEGORY_ARCHIVED", :conflict
    assert t.reload.discarded?
  end

  test "還原到期的範本回到歷史" do
    t = generated_template(start_month: "2026-11", end_month: "2026-11")
    t.discard!

    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json

    assert_equal "history", response.parsed_body["status"]
    assert_equal 1, t.expenses.count
  end

  test "永久刪除：只有垃圾桶內的可以，紀錄保留固定標示，不再連回範本，稽核保存內容" do
    t = generated_template(start_month: "2026-11")
    expense = t.expenses.sole
    delete "/api/recurring-templates/#{t.id}/purge", headers: auth_headers(@admin)
    assert_response :not_found

    t.discard!
    delete "/api/recurring-templates/#{t.id}/purge", headers: auth_headers(@admin)
    assert_response :ok

    assert_not RecurringTemplate.exists?(t.id)
    expense.reload
    assert_nil expense.recurring_template_id
    assert_equal "2026-11", expense.recurring_period
    assert_equal "辦公室租金", AuditLog.where(target_type: "recurring_template", target_id: t.id, action: "purge").sole.before["name"]

    get "/api/expenses/#{expense.id}", headers: auth_headers(@admin)
    assert_equal "2026-11", response.parsed_body["recurring_period"]
    assert_nil response.parsed_body["recurring_template_id"]
  end

  test "永久刪除等鎖時範本剛被還原：不刪，回 404，不寫稽核" do
    t = template(day_of_month: 20)
    t.discard!
    BeforeLock.hook = -> { RecurringTemplate.find(t.id).update_columns(deleted_at: nil) }

    delete "/api/recurring-templates/#{t.id}/purge", headers: auth_headers(@admin)

    assert_response :not_found
    assert RecurringTemplate.exists?(t.id)
    assert_not AuditLog.exists?(target_id: t.id, action: "purge")
  end

  test "重複送出刪除：第二次等鎖時已在垃圾桶，回成功但不多寫稽核，刪除時間不變" do
    t = template(day_of_month: 20)
    deleted_at = 1.hour.ago.round
    BeforeLock.hook = -> { RecurringTemplate.find(t.id).update_columns(deleted_at: deleted_at) }

    delete "/api/recurring-templates/#{t.id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_not AuditLog.exists?(target_id: t.id, action: "delete")
    assert_equal deleted_at, t.reload.deleted_at
  end

  test "重複送出還原：第二次等鎖時已還原，回成功但不多寫稽核" do
    t = template(day_of_month: 20)
    t.discard!
    BeforeLock.hook = -> { RecurringTemplate.find(t.id).update_columns(deleted_at: nil) }

    patch "/api/recurring-templates/#{t.id}/restore", headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal 0, response.parsed_body["backfilled_count"]
    assert_not AuditLog.exists?(target_id: t.id, action: "restore")
  end

  test "支出列表與單筆回傳固定標示；來源篩選以 recurring_period 判斷" do
    t = generated_template(start_month: "2026-11")
    recurring = t.expenses.sole
    assert_equal "general", recurring.source
    general = @company.expenses.create!(source: "general", created_by: @admin, category: @category, account: @account,
      document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current, vendor: "甲")

    get "/api/expenses", headers: auth_headers(@admin)
    row = response.parsed_body["data"].find { |e| e["id"] == recurring.id }
    assert_equal "2026-11", row["recurring_period"]
    assert_equal t.id, row["recurring_template_id"]

    get "/api/expenses", params: { source: "recurring" }, headers: auth_headers(@admin)
    assert_equal [ recurring.id ], response.parsed_body["data"].map { |e| e["id"] }

    get "/api/expenses", params: { source: "general" }, headers: auth_headers(@admin)
    assert_equal [ general.id ], response.parsed_body["data"].map { |e| e["id"] }

    get "/api/expenses/#{recurring.id}", headers: auth_headers(@admin)
    assert_equal "2026-11", response.parsed_body["recurring_period"]
  end

  test "收入列表與單筆回傳固定標示，recurring=true 只看固定" do
    income_category = @company.categories.of_kind("income").active.first
    t = generated_template(direction: "income", category: income_category, start_month: "2026-11")
    recurring = t.incomes.sole
    other = @company.incomes.create!(created_by: @admin, category: income_category, account: @account, customer: "甲",
      document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)

    get "/api/incomes", headers: auth_headers(@admin)
    assert_equal [ other.id, recurring.id ].sort, response.parsed_body.map { |i| i["id"] }.sort
    assert_equal "2026-11", response.parsed_body.find { |i| i["id"] == recurring.id }["recurring_period"]

    get "/api/incomes", params: { recurring: true }, headers: auth_headers(@admin)
    assert_equal [ recurring.id ], response.parsed_body.map { |i| i["id"] }

    get "/api/incomes/#{recurring.id}", headers: auth_headers(@admin)
    assert_equal t.id, response.parsed_body["recurring_template_id"]
  end

  test "範本使用的帳戶不可刪除，含歷史與垃圾桶內的範本" do
    account = create_account(company: @company)
    t = template(account: account, day_of_month: 20)
    t.discard!

    delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)

    assert_response :conflict
    assert_equal "ACCOUNT_IN_USE", response.parsed_body["error"]
    assert_equal 1, response.parsed_body["references"]["recurring_templates"]
    assert_includes response.parsed_body["message"], "1 筆固定收支範本"
  end

  test "員工不可使用" do
    employee = create_user(company: @company)
    t = template(day_of_month: 20)

    get "/api/recurring-templates", params: { direction: "expense" }, headers: auth_headers(employee)
    assert_response :forbidden
    post "/api/recurring-templates", params: body, headers: auth_headers(employee), as: :json
    assert_response :forbidden
    delete "/api/recurring-templates/#{t.id}", headers: auth_headers(employee)
    assert_response :forbidden
  end

  test "公司隔離：別家公司的範本、類別、帳戶都當成找不到" do
    other_company = create_company(name: "別家公司")
    other_admin   = create_user(company: other_company, role: "admin")
    other         = create_recurring_template(company: other_company, created_by: other_admin, day_of_month: 20)
    other_generated = create_recurring_template(company: other_company, created_by: other_admin, day_of_month: 5, name: "已產生")
    RecurringGenerator.call(other_generated, today: Date.current)

    get "/api/recurring-templates/#{other.id}", headers: auth_headers(@admin)
    assert_response :not_found
    get "/api/recurring-templates/#{other_generated.id}/records", headers: auth_headers(@admin)
    assert_response :not_found
    patch_template(other, name: "x")
    assert_response :not_found
    delete "/api/recurring-templates/#{other.id}", headers: auth_headers(@admin)
    assert_response :not_found

    post_template(category_id: other.category_id)
    assert_error "CATEGORY_NOT_FOUND", :unprocessable_content
    post_template(account_id: other.account_id)
    assert_error "ACCOUNT_NOT_FOUND", :unprocessable_content

    get "/api/recurring-templates", params: { direction: "expense" }, headers: auth_headers(@admin)
    assert_empty response.parsed_body["data"]
    assert_equal 0, response.parsed_body["meta"]["counts"]["expense"]["active"]
  end
end
