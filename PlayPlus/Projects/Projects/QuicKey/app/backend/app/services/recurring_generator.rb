class RecurringGenerator
  # 產生範本到今天為止該產生的期數（docs/資料模型.md §2.8）。每日排程、建立範本補齊、
  # 還原與回到進行中的「當期補一筆」、修改週期或週期日共用。紀錄的建立者與稽核操作人都是範本建立者。
  # 重複呼叫不會重複產生：鎖住範本後只產生 last_generated_period 之後的期數。

  def self.call(template, today:)
    new(template, today).call
  end

  def initialize(template, today)
    @template = template
    @today    = today
  end

  # 回傳產生的筆數。範本不可有未儲存的變更（with_lock 會重新讀取）。
  def call
    @template.with_lock do
      next 0 if @template.discarded?

      periods = @template.due_periods(@today)
      periods.each { |period| create_record!(period) }
      @template.update_columns(last_generated_period: periods.last, updated_at: Time.current) if periods.any?
      periods.size
    end
  end

  private

  def create_record!(period)
    record = @template.direction == "expense" ? build_expense(period) : build_income(period)
    record.save!
    AuditLog.record!(record, action: "create", by: @template.created_by,
      after: record.audit_snapshot.merge(via: "recurring", recurring_template_id: @template.id,
                                         recurring_period: period))
  end

  def build_expense(period)
    # 應付日期以產生當天為登錄日依付款日計算；關閉付款日時為發生日期（由 Expense 處理）。
    auto = PayoutSchedule.snapshot(@today, @template.company.payout_day)
    @template.company.expenses.new(common_attrs(period).merge(
      source: "general", vendor: @template.counterparty, payout_status: "pending",
      planned_payout_date: auto || @template.due_date(period), auto_planned_payout_date: auto,
      planned_payout_manual: false
    ))
  end

  def build_income(period)
    @template.company.incomes.new(common_attrs(period).merge(
      customer: @template.counterparty, collection_status: "uncollected",
      planned_collection_date: @template.due_date(period)
    ))
  end

  # 發生日期為週期日；發票的發票日期同發生日期（收據由 model 清空）。
  def common_attrs(period)
    pre_tax, tax = TaxAmounts.from_gross(@template.amount, @template.tax_rate)
    date = @template.due_date(period)
    {
      recurring_template: @template, recurring_period: period, created_by: @template.created_by,
      category_id: @template.category_id, account_id: @template.account_id,
      document_type: @template.document_type, tax_rate: @template.tax_rate, tax_id: @template.tax_id,
      amount: @template.amount, pre_tax_amt: pre_tax, tax_amt: tax,
      date: date, invoice_date: date, note: @template.name, items: []
    }
  end
end
