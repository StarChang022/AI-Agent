class CreateExpenses < ActiveRecord::Migration[8.1]
  # 已成立支出（Expense，docs/資料模型.md §2.2）。對齊 frontend/src/types/domain.ts
  # 的 Expense interface（現行版本：無 tags、含 planned_payout_date）。
  #
  # 本次做「一般支出（source='general'）」的後台 CRUD。兩個欄位先建、關聯留待後續：
  # - source：'general'（行政直接登錄）| 'reimbursement'（核准代墊款轉入）
  # - source_ref_id：source='reimbursement' 時指回 reimbursements.id；connnection
  #   那條線（含 FK 與 reimbursements.expense_id 回填）留待「核准自動建支出」模組再補。
  #
  # items / attachments 以 jsonb 內嵌（對齊前端內嵌陣列，與 reimbursement 的
  # approval_progress 一致）。
  def change
    create_table :expenses, id: :uuid do |t|
      t.references :company,    null: false, foreign_key: true, type: :uuid
      t.references :category,   null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.string  :source,        null: false, default: "general"     # 'general' | 'reimbursement'
      t.uuid    :source_ref_id                                       # → reimbursements（之後補 FK）
      t.string  :document_type, null: false                         # 'invoice' | 'receipt'
      t.string  :vendor
      t.string  :tax_id
      t.string  :invoice_no
      t.string  :tax_rate,      null: false                         # 'business_5' | 'exempt_0'
      t.decimal :pre_tax_amt,   precision: 12, scale: 2
      t.decimal :tax_amt,       precision: 12, scale: 2
      t.decimal :amount,        null: false, precision: 12, scale: 2
      t.date    :date,          null: false
      t.text    :note
      t.jsonb   :attachments,         null: false, default: []      # ExpenseAttachment[] { data_url, filename, mime_type }
      t.jsonb   :items,               null: false, default: []      # ExpenseItem[] { name, quantity, unit_price, subtotal }
      t.string  :payout_status,       null: false, default: "pending" # 'pending' | 'paid'
      t.date    :planned_payout_date                                # 手動預計付款日；null = 自動排程

      t.timestamps
    end

    add_index :expenses, [ :company_id, :source ]
    add_index :expenses, [ :company_id, :payout_status ]
    add_index :expenses, [ :company_id, :date ]
    add_index :expenses, :source_ref_id
  end
end
