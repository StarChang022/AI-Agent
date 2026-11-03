class AddAddressToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :county, :string
    add_column :users, :district, :string
    add_column :users, :zipcode, :string
    add_column :users, :address, :string
  end
end