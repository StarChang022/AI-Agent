class CreateIncomes < ActiveRecord::Migration[8.1]
  # 收入（Income，docs/資料模型.md §2.6）。欄位與 Expense（§2.2）對齊，差異在：
  # - customer（對應 Expense.vendor，必填）
  # - 收款相關：collection_status / collected_at（對應 Expense 的 payout_status / paid_at）
  # - 不做 source / source_ref_id（代墊款只會成立成支出，不會轉為收入）
  # - 不做 paid_by 類人員欄位（規格 §2.6 未定義 received_by，收款對帳由 account 承接）
  # - account_id / recurring_template_id：Account / RecurringTemplate 模型尚未建立，
  #   等相應模型落地時另外補 migration（不預先建無目標的欄位）
  #
  # items / attachments 以 jsonb 內嵌陣列儲存（§2.6.1 IncomeItem、§2.4 Attachment；
  # 比照 Expense 不開獨立表）。
  def change
    create_table :incomes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company,    null: false, foreign_key: true, type: :uuid
      t.references :category,   null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.string  :document_type, null: false                             # 'invoice' | 'receipt'
      t.string  :customer,      null: false                             # 對應 Expense.vendor，必填
      t.string  :tax_id
      t.string  :invoice_no
      t.string  :tax_rate,      null: false                             # 'business_5' | 'exempt_0'
      t.decimal :pre_tax_amt,   precision: 12, scale: 2
      t.decimal :tax_amt,       precision: 12, scale: 2
      t.decimal :amount,        null: false, precision: 12, scale: 2
      t.date    :date,          null: false                             # 開立日（損益認列日）
      t.text    :note
      t.jsonb   :attachments,         null: false, default: []          # IncomeAttachment[]
      t.jsonb   :items,               null: false, default: []          # IncomeItem[] { name, quantity, unit_price, subtotal }

      t.string  :collection_status,   null: false, default: "uncollected" # 'uncollected' | 'collected'
      t.date    :collected_at                                           # 收款日（現金流認列日）

      t.datetime :deleted_at                                            # 軟刪時間（進垃圾桶）

      t.timestamps
    end

    add_index :incomes, [ :company_id, :date ]
    add_index :incomes, [ :company_id, :collection_status ]
    add_index :incomes, :deleted_at
  end
end
