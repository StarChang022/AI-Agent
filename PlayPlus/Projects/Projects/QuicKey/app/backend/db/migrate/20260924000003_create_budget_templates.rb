class CreateBudgetTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_templates, id: :uuid do |t|
      t.references :company,   null: false, foreign_key: true, type: :uuid
      t.references :category,  null: false, foreign_key: true, type: :uuid
      t.string   :cycle,       null: false                       # 'month' | 'year'
      t.decimal  :amount,      null: false, precision: 12, scale: 2

      t.timestamps
    end

    add_index :budget_templates, [ :company_id, :category_id, :cycle ],
              unique: true,
              name: "index_budget_templates_on_company_category_cycle"
  end
end
