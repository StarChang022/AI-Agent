class AddAutoPlannedPayoutDateToExpenses < ActiveRecord::Migration[8.1]
  # 自動排程快照備份（docs/資料模型.md §3.1）：
  # - auto_planned_payout_date：登錄 / 核准當下用公司當時 payout_day 快照的「自動值」。
  #   建立時與 planned_payout_date 同值；之後「調整付款日」只動 planned，不動 auto。
  # - 作用：使用者按「改回自動排程」時直接還原 auto，不再用「當下公司規則」重算，
  #   避免因公司規則變動而讓同一筆的自動值漂移（違反新規則「不動已登錄支出」）。
  # - backfill：既有 row 以 planned_payout_date 複製進 auto。manual=true 的 row 其實
  #   拿不到真正的原始自動值（已被覆寫），複製為同值等同「改回自動排程」為 no-op；
  #   使用者若要重新套用自動值，需手動 adjust 一次後再改回自動。
  def change
    add_column :expenses, :auto_planned_payout_date, :date

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE expenses
             SET auto_planned_payout_date = planned_payout_date
           WHERE planned_payout_date IS NOT NULL
        SQL
      end
    end
  end
end
