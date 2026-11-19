# 固定收支範本（docs/資料模型.md §2.8）。期數一律為 YYYY-MM 字串，可直接比大小。
# resume_period：還原、歷史範本回到進行中、改週期時記下「從這一期起才產生」，中間的期數不補；
# 和 last_generated_period 分開，「已產生到第幾期」才會是實際產生過的期數。
class CreateRecurringTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_templates, id: :uuid do |t|
      t.references :company, null: false, type: :uuid, foreign_key: true
      t.references :category, null: false, type: :uuid, foreign_key: true
      t.references :account, null: false, type: :uuid, foreign_key: true
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :direction, null: false
      t.string :name, null: false
      t.string :document_type, null: false
      t.string :tax_rate, null: false
      t.string :counterparty, null: false
      t.string :tax_id
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :frequency, null: false
      t.integer :day_of_month, null: false
      t.integer :month_of_year
      t.string :start_month, null: false
      t.string :end_month
      t.string :last_generated_period
      t.string :resume_period
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :recurring_templates, [ :company_id, :direction ]
    add_index :recurring_templates, :deleted_at
  end
end
