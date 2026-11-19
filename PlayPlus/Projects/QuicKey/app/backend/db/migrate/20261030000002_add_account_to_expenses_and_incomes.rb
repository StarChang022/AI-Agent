# 收支都要指定帳戶（PRD 規則 20）：每家既有公司建一個預設帳戶，把既有收支全部歸入後改為必填。
# 預設帳戶名稱「預設帳戶」、類型 bank（當時的欄位，之後已移除），值寫死在這裡，不受 model 常數日後改動影響；
# 起始金額為 0，由使用者上線時輸入。
# 這是系統動作，不寫稽核日誌。
class AddAccountToExpensesAndIncomes < ActiveRecord::Migration[8.1]
  def up
    add_reference :expenses, :account, type: :uuid, foreign_key: true
    add_reference :incomes,  :account, type: :uuid, foreign_key: true

    execute <<~SQL.squish
      INSERT INTO accounts (company_id, name, account_type, currency, opening_month, created_at, updated_at)
      SELECT id, '預設帳戶', 'bank', 'TWD',
             date_trunc('month', now() AT TIME ZONE 'Asia/Taipei')::date, now(), now()
      FROM companies
    SQL
    execute "UPDATE expenses SET account_id = accounts.id FROM accounts WHERE accounts.company_id = expenses.company_id"
    execute "UPDATE incomes SET account_id = accounts.id FROM accounts WHERE accounts.company_id = incomes.company_id"

    change_column_null :expenses, :account_id, false
    change_column_null :incomes,  :account_id, false
  end

  def down
    remove_reference :expenses, :account, foreign_key: true
    remove_reference :incomes,  :account, foreign_key: true
    execute "DELETE FROM accounts"
  end
end
