class NotifyOverduePayoutsJob < ApplicationJob
  # 每日排程觸發（config/recurring.yml）。掃全部公司，找出仍 pending 且
  # planned_payout_date 已過期的支出，聚合通知該公司全部 admin。
  # 時區：planned_payout_date 是 Date 類型，比較以台北當日為基準（避免 server
  # UTC 時刻跨日造成少一天）。對齊 docs/通知提醒.md 第 4 條規格。
  queue_as :default

  def perform
    today = Time.find_zone!("Asia/Taipei").today

    Company.find_each do |company|
      expenses = company.expenses
                        .where(payout_status: "pending")
                        .where.not(planned_payout_date: nil)
                        .where("planned_payout_date < ?", today)
                        .to_a
      next if expenses.empty?

      Notifications.notify_overdue_payouts(company, expenses, today: today)
    end
  end
end
