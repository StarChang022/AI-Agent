# 代墊款請款新增發票日期（PRD 第 23 條「代墊款請款」、docs/資料模型.md §2.1，2026-11-05）。
# 發票必填，收據為 null；既有的發票請款以發生日期（incurred_at）補上。
class AddInvoiceDateToReimbursements < ActiveRecord::Migration[8.1]
  # 補值語句，測試也用這一句驗證。
  BACKFILL_SQL = "UPDATE reimbursements SET invoice_date = incurred_at WHERE document_type = 'invoice'".freeze

  def up
    add_column :reimbursements, :invoice_date, :date
    execute BACKFILL_SQL
  end

  def down
    remove_column :reimbursements, :invoice_date
  end
end
