# 帳戶不再區分類型（docs/資料模型.md §2.9）。account_type 沒有參與任何計算，既有資料直接刪除。
# 回滾時欄位補回，既有帳戶一律填 bank。
class RemoveAccountTypeFromAccounts < ActiveRecord::Migration[8.1]
  def change
    remove_column :accounts, :account_type, :string, null: false, default: "bank"
  end
end
