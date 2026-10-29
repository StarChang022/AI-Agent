class PayoutDayChangeLog < ApplicationRecord
  # 審計：每次管理員變更 Company#payout_day 寫一筆。from_day/to_day 其中之一可為 nil
  # （表「關閉」→ 數字 或 數字 → 「關閉」）；相同值的變更不寫入（在呼叫端擋）。
  belongs_to :company
  belongs_to :changed_by, class_name: "User"

  validates :changed_at, presence: true
end
