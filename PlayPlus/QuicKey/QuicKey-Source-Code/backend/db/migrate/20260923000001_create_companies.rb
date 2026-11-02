class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies, id: :uuid do |t|
      t.string :name,         null: false
      t.string :company_type, null: false
      t.string :tax_id
      t.string :plan,         null: false, default: "free"

      t.timestamps
    end
  end
end
