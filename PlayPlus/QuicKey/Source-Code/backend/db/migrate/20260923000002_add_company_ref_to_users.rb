class AddCompanyRefToUsers < ActiveRecord::Migration[8.1]
  def change
    # scaffold 階段尚無 production 資料，直接 null: false + FK。
    # password_digest 改為 nullable（未來 Google 註冊路徑不會有密碼）
    add_reference :users, :company, null: false, foreign_key: true, type: :uuid
    change_column_null :users, :password_digest, true
  end
end
