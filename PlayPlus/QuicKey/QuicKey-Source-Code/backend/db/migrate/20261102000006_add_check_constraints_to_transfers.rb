# 資金移轉的金額與帳戶規則（docs/資料模型.md §2.10）。model 已驗證，資料庫再擋一層，
# console 或批次程式繞過 model 時才不會寫入錯誤的金額。
class AddCheckConstraintsToTransfers < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :transfers, "amount > 0", name: "transfers_amount_positive"
    add_check_constraint :transfers, "fee >= 0", name: "transfers_fee_not_negative"
    add_check_constraint :transfers, "from_account_id <> to_account_id", name: "transfers_accounts_differ"
  end
end
