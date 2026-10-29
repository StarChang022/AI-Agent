class Notification < ApplicationRecord
  # 站內通知（docs/通知提醒.md）。單一表承載多種事件類型（kind），結構化資料存 payload jsonb。
  # 已讀狀態 read_at 存於後端，實現跨裝置同步（取代舊的 localStorage 已讀快取）。
  #
  # 來源：代墊款送審 / 核准 / 駁回 / 發放；由各業務 controller 透過 Notifications service 建立。
  # 收件人為單一 user_id；一事件通知多人（如全體 admin）會建立多筆記錄，各自獨立標記已讀。

  KINDS = %w[
    reimbursement_submitted
    reimbursement_approved
    reimbursement_rejected
    reimbursement_paid
    payout_overdue
  ].freeze

  belongs_to :company
  belongs_to :user

  validates :kind, inclusion: { in: KINDS }

  scope :unread,   -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  def read?
    read_at.present?
  end
end
