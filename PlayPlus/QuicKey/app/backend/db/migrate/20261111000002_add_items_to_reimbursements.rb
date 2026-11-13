# 代墊款品項（docs/資料模型.md §2.1.1）。比照 expenses.items，以 jsonb 內嵌陣列儲存：
# [{ name, quantity, unit_price, subtotal }]，選填；既有請款補空陣列。
class AddItemsToReimbursements < ActiveRecord::Migration[8.1]
  def change
    add_column :reimbursements, :items, :jsonb, default: [], null: false
  end
end
