class AddKindToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :kind, :string, null: false, default: "expense"
    add_index  :categories, [ :company_id, :kind ]
  end
end
