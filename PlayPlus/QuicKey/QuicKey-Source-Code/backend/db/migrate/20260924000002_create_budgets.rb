class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets, id: :uuid do |t|
      t.references :company,   null: false, foreign_key: true, type: :uuid
      t.references :category,  null: false, foreign_key: true, type: :uuid
      t.string   :cycle,       null: false                       # 'month' | 'year'
      t.decimal  :amount,      null: false, precision: 12, scale: 2
      t.date     :period_start, null: false
      t.date     :period_end,   null: false

      t.timestamps
    end

    add_index :budgets, [ :company_id, :category_id, :cycle, :period_start ],
              unique: true,
              name: "index_budgets_on_company_category_cycle_period_start"
  end
end
