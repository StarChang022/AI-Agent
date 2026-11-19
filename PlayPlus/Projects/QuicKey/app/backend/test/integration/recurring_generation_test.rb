require "test_helper"

# 固定收支的產生（PRD 第 17 條）：週期與月底、金額、不重複、補產生、到期判斷。
class RecurringGenerationTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  def template(**attrs)
    create_recurring_template(company: @company, created_by: @admin, **attrs)
  end

  def run_job
    GenerateRecurringRecordsJob.perform_now
  end

  test "週期日遇到較短的月份落在當月最後一天" do
    t = template(day_of_month: 31, start_month: "2026-11")

    assert_equal Date.new(2027, 2, 28), t.due_date("2027-02")
    assert_equal Date.new(2028, 2, 29), t.due_date("2028-02")
    assert_equal Date.new(2026, 11, 30), t.due_date("2026-11")
    assert_equal Date.new(2026, 12, 31), t.due_date("2026-12")
  end

  test "每年 2/29 在平年落在 2/28，當天產生" do
    t = template(frequency: "yearly", month_of_year: 2, day_of_month: 29, start_month: "2027-01")

    travel_to Date.new(2027, 2, 27).noon
    run_job
    assert_nil t.reload.last_generated_period

    travel_to Date.new(2027, 2, 28).noon
    run_job
    assert_equal Date.new(2027, 2, 28), t.expenses.sole.date
  end

  test "每年 4/31 視為 4/30" do
    t = template(frequency: "yearly", month_of_year: 4, day_of_month: 31, start_month: "2027-01")
    assert_equal Date.new(2027, 4, 30), t.due_date("2027-04")
  end

  test "週期日當天產生，未到不產生" do
    t = template(day_of_month: 12, start_month: "2026-11")

    travel_to Date.new(2026, 11, 11).noon
    run_job
    assert_empty t.expenses

    travel_to Date.new(2026, 11, 12).noon
    run_job
    assert_equal [ "2026-11" ], t.expenses.pluck(:recurring_period)
  end

  test "以台北日期判斷：UTC 還在前一天也算週期日當天" do
    t = template(day_of_month: 12, start_month: "2026-11")

    travel_to Time.utc(2026, 11, 11, 16, 30) # 台北 11/12 00:30
    run_job

    assert_equal [ Date.new(2026, 11, 12) ], t.expenses.pluck(:date)
  end

  test "支出帶入範本欄位，未稅與稅額算法同 Excel 匯入，發票號碼與附件留空" do
    @company.update!(payout_day: 25)
    t = template(day_of_month: 11, document_type: "invoice", tax_rate: "business_5", tax_id: "12345678",
                 amount: 1000, start_month: "2026-11", name: "雲端訂閱")

    travel_to Date.new(2026, 11, 11).noon
    run_job
    e = t.expenses.sole

    assert_equal [ BigDecimal("952"), BigDecimal("48"), BigDecimal("1000") ], [ e.pre_tax_amt, e.tax_amt, e.amount ]
    assert_equal "general", e.source
    assert_equal "pending", e.payout_status
    assert_equal "大樓管理公司", e.vendor
    assert_equal "12345678", e.tax_id
    assert_equal "雲端訂閱", e.note
    assert_equal t.category_id, e.category_id
    assert_equal t.account_id, e.account_id
    assert_equal Date.new(2026, 11, 11), e.date
    assert_equal Date.new(2026, 11, 25), e.planned_payout_date
    assert_equal Date.new(2026, 11, 25), e.auto_planned_payout_date
    assert_not e.planned_payout_manual
    assert_nil e.invoice_no
    assert_empty e.attachments
    assert_empty e.items
  end

  test "收入帶入客戶，待收款；免稅的未稅等於含稅" do
    t = template(direction: "income", day_of_month: 11, amount: 500, start_month: "2026-11")

    travel_to Date.new(2026, 11, 11).noon
    run_job
    i = t.incomes.sole

    assert_equal "大樓管理公司", i.customer
    assert_equal "uncollected", i.collection_status
    assert_equal [ BigDecimal("500"), BigDecimal("0") ], [ i.pre_tax_amt, i.tax_amt ]
  end

  test "免稅且金額帶小數：未稅等於含稅，稅額為 0" do
    t = template(day_of_month: 1, amount: "100.50", start_month: "2026-11")

    RecurringGenerator.call(t, today: Date.current)
    e = t.expenses.sole

    assert_equal [ BigDecimal("100.5"), BigDecimal("0") ], [ e.pre_tax_amt, e.tax_amt ]
  end

  test "應稅金額很小時未稅不超過含稅，稅額不為負" do
    t = template(day_of_month: 1, document_type: "invoice", tax_rate: "business_5", tax_id: "12345678",
                 amount: "1.6", start_month: "2026-11")

    RecurringGenerator.call(t, today: Date.current)
    e = t.expenses.sole

    assert_equal [ BigDecimal("1.6"), BigDecimal("0") ], [ e.pre_tax_amt, e.tax_amt ]
  end

  test "收據的稅別一律免稅" do
    assert_equal "exempt_0", template(document_type: "receipt", tax_rate: "business_5").tax_rate
  end

  test "稽核：操作人與建立者都是範本建立者，標示固定收支自動產生" do
    t = template(day_of_month: 11, start_month: "2026-11")

    travel_to Date.new(2026, 11, 11).noon
    run_job
    e = t.expenses.sole
    log = AuditLog.where(target_type: "expense", target_id: e.id).sole

    assert_equal @admin.id, e.created_by_id
    assert_equal @admin.id, log.actor_user_id
    assert_equal "create", log.action
    assert_equal "recurring", log.after["via"]
    assert_equal "2026-11", log.after["recurring_period"]
    assert_equal t.id, log.after["recurring_template_id"]
  end

  test "重跑不重複，垃圾桶內的紀錄也不會重新產生" do
    t = template(day_of_month: 11, start_month: "2026-11")
    travel_to Date.new(2026, 11, 11).noon
    2.times { run_job }
    assert_equal 1, t.expenses.count

    t.expenses.sole.discard!
    run_job
    assert_equal 1, t.expenses.count
    assert_equal 1, Expense.where(recurring_template_id: t.id).discarded.count
  end

  test "資料庫也擋同範本同一期" do
    t = template(day_of_month: 11, start_month: "2026-11")
    travel_to Date.new(2026, 11, 11).noon
    run_job
    dup = t.expenses.sole.dup

    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "停機漏跑的期數下次補上，預計付款日以產生當天為登錄日" do
    @company.update!(payout_day: 25)
    t = template(day_of_month: 5, start_month: "2026-12")

    travel_to Date.new(2027, 3, 6).noon
    run_job

    assert_equal %w[2026-12 2027-01 2027-02 2027-03], t.expenses.order(:date).pluck(:recurring_period)
    assert_equal [ Date.new(2027, 3, 25) ], t.expenses.distinct.pluck(:planned_payout_date)
    assert_equal "2027-03", t.reload.last_generated_period
  end

  test "沒有到期期數的範本略過，不開交易加鎖" do
    template(name: "歷史", start_month: "2026-01", end_month: "2026-02", last_generated_period: "2026-02")
    template(name: "週期日未到", day_of_month: 20, start_month: "2026-11")
    due = template(name: "到期", day_of_month: 5, start_month: "2026-11")
    locks = []
    counter = ->(*, payload) { locks << payload[:sql] if payload[:sql].include?("FOR UPDATE") }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { run_job }

    assert_equal 1, locks.size
    assert_equal 1, due.expenses.count
  end

  test "一筆範本失敗不擋其他範本，下次補上" do
    broken = template(day_of_month: 11, start_month: "2026-11", name: "壞的")
    good   = template(day_of_month: 11, start_month: "2026-11", name: "好的")
    broken.update_columns(document_type: "invoice", tax_id: nil)

    travel_to Date.new(2026, 11, 11).noon
    run_job
    assert_empty broken.expenses
    assert_equal 1, good.expenses.count

    broken.update_columns(tax_id: "12345678")
    run_job
    assert_equal 1, broken.expenses.count
  end

  test "垃圾桶內的範本不產生" do
    t = template(day_of_month: 11, start_month: "2026-11")
    t.discard!

    travel_to Date.new(2026, 11, 11).noon
    run_job

    assert_empty t.expenses
  end

  test "結束月份那一期產生後到期，不再產生" do
    t = template(day_of_month: 11, start_month: "2026-11", end_month: "2026-11")
    assert_not t.expired?

    travel_to Date.new(2026, 11, 11).noon
    run_job
    assert t.reload.expired?
    assert_equal "history", t.status

    travel_to Date.new(2026, 12, 11).noon
    run_job
    assert_equal 1, t.expenses.count
  end

  test "每年週期：結束月份之前沒有下一期就算到期" do
    t = template(frequency: "yearly", month_of_year: 11, day_of_month: 5, start_month: "2026-01", end_month: "2027-06")
    assert_equal "2026-11", t.next_period

    t.update!(last_generated_period: "2026-11")

    assert_nil t.next_period
    assert t.expired?
  end

  test "每年週期：沒有結束月份時不到期，每年一筆" do
    t = template(frequency: "yearly", month_of_year: 3, day_of_month: 15, start_month: "2027-01")

    travel_to Date.new(2029, 4, 1).noon
    run_job

    assert_equal %w[2027-03 2028-03 2029-03], t.expenses.order(:date).pluck(:recurring_period)
    assert_equal "2030-03", t.reload.next_period
  end

  test "逾期付款通知不含垃圾桶內的支出" do
    kept    = template(day_of_month: 1, start_month: "2026-11", name: "留著").then { |t| RecurringGenerator.call(t, today: Date.current); t.expenses.sole }
    trashed = template(day_of_month: 1, start_month: "2026-11", name: "刪掉").then { |t| RecurringGenerator.call(t, today: Date.current); t.expenses.sole }
    [ kept, trashed ].each { |e| e.update!(planned_payout_date: Date.new(2026, 11, 1)) }
    trashed.discard!
    notified = nil

    Notifications.stub_notify_overdue(->(_company, expenses, today:) { notified = expenses }) do
      NotifyOverduePayoutsJob.perform_now
    end

    assert_equal [ kept.id ], notified.map(&:id)
  end

  test "上一次使用的帳戶不看固定產生的紀錄" do
    manual = create_account(company: @company, name: "手動用")
    other  = create_account(company: @company, name: "範本用")
    @company.expenses.create!(source: "general", created_by: @admin, category: @company.categories.of_kind("expense").active.first,
      account: manual, document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current, vendor: "甲")

    t = template(account: other, day_of_month: 1, start_month: "2026-11")
    RecurringGenerator.call(t, today: Date.current)

    assert_equal manual.id, @admin.reload.last_used_account.id
  end
end
