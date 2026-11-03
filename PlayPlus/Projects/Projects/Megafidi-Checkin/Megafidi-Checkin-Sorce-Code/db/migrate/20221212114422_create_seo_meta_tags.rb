class CreateSeoMetaTags < ActiveRecord::Migration[7.0]
  def change
    create_table :seo_meta_tags do |t|
      t.string :item_type, index: true
      t.integer :item_id, index: :true

      t.string :title
      t.text :description
      t.string :keywords

      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
