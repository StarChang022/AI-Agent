# 補建正式站漏建的 notifications 表。
#
# 原因：2026-10-14～10-16 之間，main 的 schema.rb 版本已是 2026_10_13_000001，卻漏了
# notifications 表。正式站第一次部署（PR #38）時資料庫是空的，db:prepare 照 schema.rb 建表，
# 並把版本不大於 2026_10_13_000001 的 migration 都記為已執行，所以
# 20261008000002_create_notifications 被跳過、表沒建出來，通知相關 API 回 500。
# 比對當時的 schema.rb 與逐支跑 migration 的結果，只差這張表（欄位、4 個索引、2 個外鍵），
# 其他表、欄位、索引、約束都一致。
#
# 本機或測試資料庫已有這張表時直接跳過；欄位、外鍵、索引照 20261008000002_create_notifications，
# 與 schema.rb 一致。
class CreateNotificationsIfMissing < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:notifications)

    create_table :notifications, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :user,    type: :uuid, null: false, foreign_key: true
      t.string  :kind,    null: false
      t.jsonb   :payload, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, [ :user_id, :read_at ]
  end

  # 不刪表：這張表本來由 20261008000002_create_notifications 負責，本機多半是那支建的；
  # rollback 這支就刪表會把大家的通知資料一起刪掉。
  def down; end
end
