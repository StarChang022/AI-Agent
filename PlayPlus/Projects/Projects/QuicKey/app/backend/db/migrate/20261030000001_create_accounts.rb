# 帳戶與起始金額（docs/資料模型.md §2.9）。
class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.references :company, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.string :account_type, null: false
      t.string :currency, null: false, default: "TWD"
      t.decimal :opening_amount, precision: 12, scale: 2, null: false, default: 0
      t.date :opening_month, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    # 名稱公司內不分大小寫唯一，含垃圾桶內的帳戶。
    add_index :accounts, "company_id, lower(name)", unique: true, name: "index_accounts_on_company_id_and_lower_name"
    add_index :accounts, :deleted_at
  end
end
