class CreateImages < ActiveRecord::Migration[7.0]
  def change
    create_table :images do |t|
      t.integer :item_id, index: true
      t.string :item_type, index: true

      t.string :name

      t.integer :priority, default: 0

      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
