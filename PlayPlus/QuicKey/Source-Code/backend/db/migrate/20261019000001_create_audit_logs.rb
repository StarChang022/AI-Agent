class CreateAuditLogs < ActiveRecord::Migration[8.1]
  # 稽核日誌（docs/資料模型.md §2.7）：只能新增、不能修改或刪除。
  # 覆蓋 expense / income / reimbursement 的建立 / 更新 / 狀態切換 / 作廢 / 刪除 / 還原 / 永久刪除。
  def change
    create_table :audit_logs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string  :target_type, null: false # 'expense' | 'income' | 'reimbursement'
      t.uuid    :target_id,   null: false # 保留，即使 target 已 purge
      t.string  :action,      null: false # 'create' | 'update' | 'delete' | 'status_change' | 'void' | 'revert_void' | 'refund' | 'restore' | 'purge'
      t.jsonb   :before
      t.jsonb   :after
      t.references :actor_user, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :created_at,  null: false
    end

    # 常用查詢：某 target 的歷程、公司全部的歷程（按時間逆序）
    add_index :audit_logs, %i[target_type target_id created_at], order: { created_at: :desc }
    add_index :audit_logs, %i[company_id created_at],            order: { created_at: :desc }
  end
end
