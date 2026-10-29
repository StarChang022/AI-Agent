class AddPaymentMethod < ActiveRecord::Migration[8.1]
  # 代墊款發放方式（docs/資料模型.md paymentMethod）。
  # 欄位只掛 Reimbursement（原生代墊款屬性）；一般支出不需要發放方式，
  # 由 expenses#pay 端轉送到連動的代墊款上。枚舉值由 model PAYMENT_METHODS
  # 守門：'bank_transfer' | 'cash'。
  def change
    add_column :reimbursements, :payment_method, :string
  end
end
