class GenerateRecurringRecordsJob < ApplicationJob
  # 每日排程觸發（config/recurring.yml），排在逾期付款通知之前。掃全部進行中的範本，
  # 產生週期日已到的期數；停機漏跑的期數這裡一併補上。以台北當日判斷。
  # 沒有到期期數的範本（含歷史）先略過，不開交易加鎖；RecurringGenerator 鎖定後會再算一次。
  # 一筆範本失敗不擋其他範本，它的期數下次重跑時補上。
  queue_as :default

  def perform
    today = Time.find_zone!("Asia/Taipei").today

    RecurringTemplate.kept.find_each do |template|
      next if template.due_periods(today).empty?

      RecurringGenerator.call(template, today: today)
    rescue StandardError => e
      Rails.logger.error("[RecurringTemplate] #{template.id} generate failed: #{e.class}: #{e.message}")
    end
  end
end
