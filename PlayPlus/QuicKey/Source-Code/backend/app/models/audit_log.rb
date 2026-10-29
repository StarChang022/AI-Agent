class AuditLog < ApplicationRecord
  # 稽核日誌（docs/資料模型.md §2.7、§收入管理規格 §3）：只能新增，任何 update / destroy
  # 都拒絕。覆蓋 Expense / Income / Reimbursement 的所有狀態轉移，給支出 / 收入 /
  # 代墊款詳情抽屜 inline 顯示該筆歷程用（不做獨立後台頁）。

  TARGET_TYPES = %w[expense income reimbursement].freeze
  ACTIONS      = %w[create update delete status_change void revert_void refund restore purge].freeze

  belongs_to :company
  belongs_to :actor, class_name: "User", foreign_key: :actor_user_id

  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :target_id,   presence: true
  validates :action,      inclusion: { in: ACTIONS }

  # 拒絕任何修改 / 刪除。兩層守門：
  # - before_update callback：Rails 的 save 進到 update 流程會呼叫 before_update，直接拋
  #   ReadOnlyRecord；`update` / `update!` 都會因此拋錯，不會悄悄回 false
  # - destroy / destroy! 覆蓋，直接拋 ReadOnlyRecord
  # （不用 readonly? 是因為 Rails 的 readonly? 會讓 _update_row 直接跳過 SQL 且不拋
  # 任何錯，callers 看起來「update 成功」）
  before_update :raise_readonly

  def destroy
    raise ActiveRecord::ReadOnlyRecord, "AuditLog cannot be destroyed"
  end
  alias_method :destroy!, :destroy

  # Controller 塞 log 的統一入口。before / after 自動序列化成 jsonb；
  # 任一方為 nil 代表 create（before nil）或 purge（after nil）。
  #
  # 例：
  #   AuditLog.record!(expense, action: "status_change",
  #     before: { payout_status: "pending" },
  #     after:  { payout_status: "paid", paid_at: "2026-10-19" },
  #     by: current_user)
  def self.record!(target, action:, by:, before: nil, after: nil)
    create!(
      company:    target.company,
      target_type: target.class.model_name.element, # "expense" / "income" / "reimbursement"
      target_id:   target.id,
      action:      action.to_s,
      before:      before,
      after:       after,
      actor:       by
    )
  end

  private

  def raise_readonly
    raise ActiveRecord::ReadOnlyRecord, "AuditLog cannot be modified"
  end
end
