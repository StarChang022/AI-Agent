# 資料匯出（docs/資料模型.md §3.7、PRD 第 24 條）：每次匯出建一筆，背景產生的檔案以
# ActiveStorage 掛在這筆上；檔案過期刪除後這筆保留，稽核日誌才對得到。
class CreateDataExports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_exports, id: :uuid do |t|
      t.references :company,      null: false, type: :uuid, foreign_key: true
      t.references :requested_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string   :scope,            null: false
      t.string   :kind,             null: false
      t.jsonb    :criteria,         null: false, default: {}
      t.integer  :record_count,     null: false, default: 0
      t.boolean  :with_attachments, null: false, default: false
      t.string   :status,           null: false, default: "queued"
      t.datetime :completed_at
      t.datetime :expires_at
      t.text     :error
      t.timestamps
    end

    add_index :data_exports, :expires_at
  end
end
