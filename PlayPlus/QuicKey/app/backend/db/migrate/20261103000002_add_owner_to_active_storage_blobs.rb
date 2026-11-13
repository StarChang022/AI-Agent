# 圖檔歸屬（docs/資料模型.md §2.4）：company_id 做公司隔離與儲存空間加總；uploaded_by_id 限定
# 暫存檔只有上傳者能掛上、刪除。ActiveStorage 本身不管歸屬，所以加在 blobs 表上。
class AddOwnerToActiveStorageBlobs < ActiveRecord::Migration[8.1]
  def change
    add_reference :active_storage_blobs, :company, type: :uuid, null: false, foreign_key: true
    add_reference :active_storage_blobs, :uploaded_by, type: :uuid, null: false, foreign_key: { to_table: :users }
    # 每日清除暫存檔依建立時間找
    add_index :active_storage_blobs, :created_at
  end
end
