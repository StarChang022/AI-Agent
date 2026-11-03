class CreateGuests < ActiveRecord::Migration[7.0]
  def change
    create_table :guests do |t|
      t.references :activity

      t.integer :trophy_num
      t.string :name
      t.string :phone
      t.string :company_name
      t.string :department_name
      t.string :certificate_num
      t.string :behalf
      t.boolean :special, default: false

      t.integer :status
      t.datetime :registration_time

      t.text :note

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
