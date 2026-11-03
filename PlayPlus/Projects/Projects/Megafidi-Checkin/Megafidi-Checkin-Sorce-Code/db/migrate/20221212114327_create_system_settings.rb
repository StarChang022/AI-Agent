class CreateSystemSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :system_settings do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :address

      t.string :line_notify_token
      
      #social
      #t.text :socials

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
