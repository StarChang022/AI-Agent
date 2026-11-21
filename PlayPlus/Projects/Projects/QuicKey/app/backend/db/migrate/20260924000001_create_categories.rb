class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.references :company,      null: false, foreign_key: true, type: :uuid
      t.string   :name,           null: false
      t.string   :account_code,   null: false, default: ""
      t.boolean  :is_archived,    null: false, default: false
      t.integer  :sort_order,     null: false, default: 0

      t.timestamps
    end

    # 同一公司內類別名稱不可重複（case-insensitive 於 model layer 檢查）。
    add_index :categories, [ :company_id, :is_archived ]
    add_index :categories, [ :company_id, :sort_order ]
  end
end
