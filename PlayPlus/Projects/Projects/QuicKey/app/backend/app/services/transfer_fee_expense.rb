class TransferFeeExpense
  # 資金移轉的手續費支出（docs/資料模型.md §2.10）。這筆支出只能經由移轉異動，全部在這裡處理，
  # 每筆異動都寫稽核，以 via 標示「資金移轉手續費自動產生」。須在呼叫端的交易內，不另發通知。

  VIA  = "transfer_fee".freeze
  NOTE = "資金移轉手續費".freeze

  # 建立或編輯移轉後呼叫：手續費大於 0 時建立或同步；改為 0 時移入垃圾桶並清空 fee_expense_id。
  def self.sync!(transfer, by:)
    expense = transfer.fee_expense
    if transfer.fee.positive?
      expense ? update!(expense, transfer, by: by) : create!(transfer, by: by)
    elsif expense
      discard_expense!(expense, by: by)
      transfer.update!(fee_expense: nil)
    end
  end

  def self.discard!(transfer, by:)
    discard_expense!(transfer.fee_expense, by: by) if transfer.fee_expense
  end

  def self.restore!(transfer, by:)
    expense = transfer.fee_expense
    return if expense.nil?

    prev_deleted_at = expense.deleted_at&.iso8601
    expense.restore_from_trash!
    AuditLog.record!(expense, action: "restore", by: by,
      before: { deleted_at: prev_deleted_at },
      after:  { deleted_at: nil, via: VIA })
  end

  # 包含先前手續費改為 0 留在垃圾桶的支出。
  def self.purge!(transfer, by:)
    transfer.expenses.find_each do |expense|
      AuditLog.record!(expense, action: "purge", by: by, before: expense.audit_snapshot)
      expense.destroy!
    end
  end

  def self.create!(transfer, by:)
    company = transfer.company
    expense = company.expenses.create!(
      source: "transfer_fee", transfer: transfer, created_by: by,
      category: CategorySeeder.ensure_transfer_fee!(company),
      account_id: transfer.from_account_id, date: transfer.transfer_date,
      planned_payout_date: transfer.transfer_date, planned_payout_manual: false,
      amount: transfer.fee, pre_tax_amt: transfer.fee, tax_amt: 0,
      document_type: "receipt", tax_rate: "exempt_0", note: NOTE,
      payout_status: "paid", paid_at: transfer.transfer_date, paid_by: by
    )
    AuditLog.record!(expense, action: "create", by: by, after: expense.audit_snapshot)
    transfer.update!(fee_expense: expense)
  end
  private_class_method :create!

  def self.update!(expense, transfer, by:)
    expense.update!(amount: transfer.fee, pre_tax_amt: transfer.fee, date: transfer.transfer_date,
                    planned_payout_date: transfer.transfer_date, paid_at: transfer.transfer_date,
                    account_id: transfer.from_account_id)
    diff = expense.saved_changes.except("updated_at")
    return if diff.empty?

    before, after = AuditLog.update_payload(diff)
    AuditLog.record!(expense, action: "update", by: by, before: before, after: after.merge(via: VIA))
  end
  private_class_method :update!

  def self.discard_expense!(expense, by:)
    expense.discard!
    AuditLog.record!(expense, action: "delete", by: by,
      before: { deleted_at: nil },
      after:  { deleted_at: expense.deleted_at&.iso8601, via: VIA })
  end
  private_class_method :discard_expense!
end
