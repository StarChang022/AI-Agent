class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.string :item_type, index: true
      t.integer :item_id, index: true

      t.string :num

      t.integer :payment_type

      t.text :payment_params
      t.text :payment_info_params
      t.text :return_params
      t.text :refund_params

      t.integer :total_amount, default: 0

      # 信用卡分期
      t.string :credit_installment

      # 分期付款
      t.integer :period_amount, default: 0
      t.string :period_type
      t.integer :frequency, default: 1
      t.integer :exec_times, default: 1

      # ATM
      t.integer :expire_date

      t.datetime :deleted_at

      t.timestamps
    end
  end
end
