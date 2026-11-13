# 收支日期欄位改版（PRD 第 23 條、docs/資料模型.md §2.2、§2.6，2026-11-05 定案）。
# - 支出、收入新增發票日期 invoice_date（發票必填，收據為 null）。
# - 收入新增應收日期 planned_collection_date（必填）。收入不記是否手動改過，見 Income 模型。
# - 支出應付日期 planned_payout_date 改為必填。
# 既有資料：發票的發票日期補發生日期；沒有應付日期的支出補發生日期；收入的應收日期補發生日期。
class AddDateFieldsToExpensesAndIncomes < ActiveRecord::Migration[8.1]
  def up
    add_column :expenses, :invoice_date, :date
    add_column :incomes,  :invoice_date, :date
    add_column :incomes,  :planned_collection_date, :date

    execute "UPDATE expenses SET invoice_date = date WHERE document_type = 'invoice'"
    execute "UPDATE incomes  SET invoice_date = date WHERE document_type = 'invoice'"
    execute "UPDATE expenses SET planned_payout_date = date WHERE planned_payout_date IS NULL"
    execute "UPDATE incomes  SET planned_collection_date = date"

    change_column_null :expenses, :planned_payout_date, false
    change_column_null :incomes,  :planned_collection_date, false

    # 待收付分組、逾期判斷依應收／應付日期查詢
    add_index :expenses, [ :company_id, :planned_payout_date ]
    add_index :incomes,  [ :company_id, :planned_collection_date ]
  end

  def down
    remove_index :incomes,  [ :company_id, :planned_collection_date ]
    remove_index :expenses, [ :company_id, :planned_payout_date ]
    change_column_null :expenses, :planned_payout_date, true
    remove_column :incomes,  :planned_collection_date
    remove_column :incomes,  :invoice_date
    remove_column :expenses, :invoice_date
  end
end
