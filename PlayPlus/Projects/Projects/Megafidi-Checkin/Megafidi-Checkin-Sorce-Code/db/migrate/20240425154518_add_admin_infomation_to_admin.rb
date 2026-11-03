class AddAdminInfomationToAdmin < ActiveRecord::Migration[7.0]
  def change
    change_table :admins, bulk: true do |t|
      t.string :phone
      t.text :note
      t.integer :status
      t.integer :role
    end
  end
end
