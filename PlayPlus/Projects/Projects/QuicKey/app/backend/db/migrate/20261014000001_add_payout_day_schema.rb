class AddPayoutDaySchema < ActiveRecord::Migration[8.1]
  # 付款日 snapshot 架構（docs/資料模型.md §3.1 付款日規則）：
  # - companies.payout_day：每月付款日 1–31 或 null（null = 關閉自動付款批次）。
  #   預設 5（對齊前端 PayoutScheduleStore DEFAULT_DAY）；既有 company 一併 backfill。
  # - expenses.planned_payout_manual：是否被管理員手動鎖定；true 時規則變更不覆蓋。
  #   backfill：既有 planned_payout_date 非 null 的 row 視為舊語意的手動覆寫，設 true。
  # - payout_day_change_logs：審計／除錯用，記錄每次管理員變更付款日的 before/after。
  def change
    add_column :companies, :payout_day, :integer, default: 5

    add_column :expenses, :planned_payout_manual, :boolean, null: false, default: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE expenses
             SET planned_payout_manual = true
           WHERE planned_payout_date IS NOT NULL
        SQL
      end
    end

    create_table :payout_day_change_logs, id: :uuid do |t|
      t.references :company,    null: false, foreign_key: true, type: :uuid
      t.references :changed_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.datetime   :changed_at, null: false
      t.integer    :from_day
      t.integer    :to_day
    end

    add_index :payout_day_change_logs, [ :company_id, :changed_at ]
  end
end
