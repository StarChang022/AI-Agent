class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string   :email,           null: false
      t.string   :password_digest, null: false
      t.string   :name,            null: false
      t.string   :role,            null: false, default: "employee"
      t.string   :status,          null: false, default: "active"
      t.datetime :last_login_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
