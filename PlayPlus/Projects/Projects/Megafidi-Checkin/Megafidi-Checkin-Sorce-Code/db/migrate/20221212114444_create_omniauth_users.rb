class CreateOmniauthUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :omniauth_users do |t|
      t.references :user
      t.string :provider, index: :true

      t.string :uid
      t.string :token

      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
