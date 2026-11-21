# 邀請「重新寄送」（docs/資料模型.md §3.3「重新寄送與過期」，2026-11-10）：
# 記錄最後一次寄出邀請信的時間，用來擋 1 分鐘內重複寄送。既有資料以建立時間補值。
class AddLastSentAtToInvitations < ActiveRecord::Migration[8.1]
  def up
    add_column :invitations, :last_sent_at, :datetime
    execute "UPDATE invitations SET last_sent_at = created_at"
    change_column_null :invitations, :last_sent_at, false
  end

  def down
    remove_column :invitations, :last_sent_at
  end
end
