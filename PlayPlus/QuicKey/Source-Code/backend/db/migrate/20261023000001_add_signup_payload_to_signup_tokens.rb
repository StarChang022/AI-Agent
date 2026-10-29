class AddSignupPayloadToSignupTokens < ActiveRecord::Migration[8.1]
  def change
    change_table :signup_tokens do |t|
      t.string :password_digest
      t.string :company_type
      t.string :company_name
      t.string :tax_id
    end
  end
end
