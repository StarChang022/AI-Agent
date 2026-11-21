# 資金移轉（docs/資料模型.md §2.10）。手續費支出以 expenses.transfer_id 指回移轉，
# 手續費改為 0 後仍保留；fee_expense_id 只記目前對應的那筆，支出刪除時自動清空。
class CreateTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :transfers, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: false
      t.references :from_account, type: :uuid, null: false, foreign_key: { to_table: :accounts }
      t.references :to_account, type: :uuid, null: false, foreign_key: { to_table: :accounts }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.decimal :fee, precision: 12, scale: 2, null: false, default: 0
      t.date :transfer_date, null: false
      t.text :note
      t.jsonb :attachments, null: false, default: []
      t.references :fee_expense, type: :uuid, foreign_key: { to_table: :expenses, on_delete: :nullify }
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :transfers, [ :company_id, :transfer_date ]
    add_index :transfers, :deleted_at

    add_reference :expenses, :transfer, type: :uuid, foreign_key: true
  end
end
