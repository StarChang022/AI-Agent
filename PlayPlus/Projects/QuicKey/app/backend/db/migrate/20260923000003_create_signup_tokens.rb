class CreateSignupTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :signup_tokens, id: :uuid do |t|
      t.string   :email,        null: false
      t.string   :token_digest, null: false
      t.string   :provider,     null: false, default: "email"
      t.datetime :expires_at,   null: false
      t.datetime :verified_at
      t.datetime :consumed_at

      t.timestamps
    end
    add_index :signup_tokens, :token_digest, unique: true
    add_index :signup_tokens, :email
  end
end
