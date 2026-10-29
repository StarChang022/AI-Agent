class AddReimbursementExpenseLinks < ActiveRecord::Migration[8.1]
  # 補上代墊款 ↔ 支出的雙向外鍵（欄位先前已於各自 create migration 建立、僅缺 FK）：
  # - reimbursements.expense_id  → expenses   （核准時回填）
  # - expenses.source_ref_id     → reimbursements（source='reimbursement' 時指回來源）
  # 兩表互為外鍵，故等兩表都存在後再補（見 docs/資料模型.md §7）。
  def change
    add_foreign_key :reimbursements, :expenses,       column: :expense_id
    add_foreign_key :expenses,       :reimbursements, column: :source_ref_id
  end
end
