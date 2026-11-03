class CreateBlogs < ActiveRecord::Migration[7.0]
  def change
    create_table :blogs do |t|
      t.string :name

      t.string :slug, index: true

      t.text :builder_content
      t.text :tinymce_content

      t.integer :status

      t.datetime :posted_at

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
