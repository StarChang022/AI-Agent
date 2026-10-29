class CreateReimbursements < ActiveRecord::Migration[8.1]
  # 代墊款請款（docs/資料模型.md §2.1）。對齊 frontend/src/types/domain.ts 的
  # Reimbursement interface（現行版本已無 tags 欄位）。
  #
  # 本次僅做 CRUD 所需結構。兩個欄位先建、關聯 / 邏輯留待後續模組：
  # - approval_progress：送審時填入單層簽核進度（jsonb，對應前端 ApprovalProgress）
  # - expense_id：核准後連動建立的支出；expenses 表尚未建立，故此處只留欄位、
  #   不加外鍵，待「代墊款→支出」模組再補 FK（雙向關聯見 §5.2）。
  def change
    create_table :reimbursements, id: :uuid do |t|
      t.references :company,  null: false, foreign_key: true, type: :uuid
      t.references :employee, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :category, null: false, foreign_key: true, type: :uuid

      t.decimal :amount,        null: false, precision: 12, scale: 2
      t.text    :description,   null: false, default: ""
      t.date    :incurred_at,   null: false
      t.string  :receipt_urls,  null: false, default: [], array: true
      t.string  :receipt_names, null: false, default: [], array: true
      t.string  :document_type, null: false                        # 'invoice' | 'receipt'
      t.string  :vendor
      t.string  :tax_id
      t.string  :invoice_no
      t.string  :tax_rate,      null: false                        # 'business_5' | 'exempt_0'
      t.decimal :pre_tax_amt,   precision: 12, scale: 2
      t.decimal :tax_amt,       precision: 12, scale: 2
      t.string  :status,        null: false, default: "draft"      # 6 狀態機（本次只用到 draft / in_review / rejected）
      t.jsonb   :approval_progress
      t.uuid    :expense_id                                        # 之後補 FK → expenses
      t.integer :version,       null: false, default: 1            # 樂觀鎖版本號

      t.timestamps
    end

    add_index :reimbursements, [ :company_id, :status ]
    add_index :reimbursements, [ :employee_id, :status ]
  end
end
