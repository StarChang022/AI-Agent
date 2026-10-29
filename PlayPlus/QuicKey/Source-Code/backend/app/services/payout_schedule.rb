class PayoutSchedule
  # 付款日 snapshot 計算。對齊 frontend/src/utils/payoutSchedule.ts。
  #
  # 核心規則（docs/資料模型.md §3.1 付款日規則）：
  # - 支出登錄當下，依公司 payout_day 同時快照 planned_payout_date 與
  #   auto_planned_payout_date 存入 Expense（兩者初始同值）。
  # - 管理員改 payout_day 時「不動」任何已登錄支出；新規則只套用到之後新登錄 / 核准的支出。
  # - 既有 pending 支出若要換付款日，走單筆「調整付款日」(adjust-payout-date)。
  # - 「改回自動排程」直接把 planned_payout_date 還原為 auto_planned_payout_date，
  #   不重算快照，確保自動值是這筆支出終身不變的屬性。

  # 給定登錄日與 day（1–31 或 nil），回傳快照 Date。
  # - day=nil → nil（公司關閉自動付款批次）
  # - 若登錄日已過當月 day → 推到下個月（跨年 wrap）
  # - 若 day 大於目標月最後一天（例如 2 月 30）→ 收斂到月末
  def self.snapshot(recorded_date, day)
    return nil if day.nil?
    base = recorded_date.to_date
    year  = base.year
    month = base.month
    if base.day > day
      month += 1
      if month > 12
        year += 1
        month = 1
      end
    end
    last_day = Date.new(year, month, -1).day
    Date.new(year, month, [ day, last_day ].min)
  end
end
