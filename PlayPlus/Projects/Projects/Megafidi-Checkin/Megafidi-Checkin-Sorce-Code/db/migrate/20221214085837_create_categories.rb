class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories do |t|
      t.string :name

      t.integer :parent_id, index: true
      t.integer :lft
      t.integer :rgt
      t.integer :depth

      t.integer :status
      t.integer :priority, default: 0

      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
