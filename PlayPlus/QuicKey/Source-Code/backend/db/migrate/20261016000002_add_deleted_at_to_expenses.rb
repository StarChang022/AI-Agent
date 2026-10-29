class AddDeletedAtToExpenses < ActiveRecord::Migration[8.1]
  # 支出軟刪除：進垃圾桶改填 deleted_at；永久刪除才真的 DELETE。
  # 對齊 docs/收入管理規格.md「刪除：待付款才能刪除，進入垃圾桶」。
  def change
    add_column :expenses, :deleted_at, :datetime
    add_index  :expenses, :deleted_at
  end
end
