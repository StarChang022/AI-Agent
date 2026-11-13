module IncomeTrash
  # 收入的還原與永久刪除。單筆 API、批次 API 共用（docs/dev/trash-batch-api.md）。
  # 每次呼叫各自一個交易。

  module_function

  # 從垃圾桶還原：清掉 deleted_at，狀態保留。
  def restore!(income, by:)
    prev_deleted_at = income.deleted_at&.iso8601
    ActiveRecord::Base.transaction do
      income.restore_from_trash!
      AuditLog.record!(income, action: "restore", by: by,
        before: { deleted_at: prev_deleted_at },
        after:  { deleted_at: nil })
    end
    income
  end

  # 永久刪除：真的 DELETE。audit log 必須在 destroy! 前寫入，否則 target.company 連動撈不到。
  def purge!(income, by:)
    ActiveRecord::Base.transaction do
      AuditLog.record!(income, action: "purge", by: by, before: income.audit_snapshot)
      income.destroy!
    end
  end
end
