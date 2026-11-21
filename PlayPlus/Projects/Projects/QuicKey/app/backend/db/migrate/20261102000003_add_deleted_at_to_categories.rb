# 類別垃圾桶（docs/資料模型.md §3.4）。進出垃圾桶不改變 is_archived。
class AddDeletedAtToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :deleted_at, :datetime
    add_index :categories, :deleted_at
  end
end
