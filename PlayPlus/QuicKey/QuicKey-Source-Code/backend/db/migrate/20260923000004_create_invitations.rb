class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.references :company,    null: false, foreign_key: true, type: :uuid
      t.references :invited_by, foreign_key: { to_table: :users }, type: :uuid
      t.string   :email,        null: false
      t.string   :name,         null: false
      t.string   :token_digest, null: false
      t.datetime :expires_at,   null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :company_id, :email ]
  end
end
