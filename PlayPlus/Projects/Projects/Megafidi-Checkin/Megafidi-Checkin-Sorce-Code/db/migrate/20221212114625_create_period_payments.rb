class CreatePeriodPayments < ActiveRecord::Migration[7.0]
  def change
    create_table :period_payments do |t|
      t.references :payment

      t.string :num

      t.text :return_params

      t.datetime :deleted_at
      
      t.timestamps
    end
  end
end
