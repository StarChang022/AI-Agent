class CreateContentImages < ActiveRecord::Migration[7.0]
  def change
    create_table :content_images do |t|
      t.integer :item_id, index: true
      t.string :item_type, index: true

      t.string :file

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
