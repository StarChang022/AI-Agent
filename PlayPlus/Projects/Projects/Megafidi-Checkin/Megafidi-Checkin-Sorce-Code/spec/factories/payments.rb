# == Schema Information
#
# Table name: payments
#
#  id                  :integer          not null, primary key
#  credit_installment  :string
#  deleted_at          :datetime
#  exec_times          :integer          default(1)
#  expire_date         :integer
#  frequency           :integer          default(1)
#  item_type           :string
#  num                 :string
#  payment_info_params :text
#  payment_params      :text
#  payment_type        :integer
#  period_amount       :integer          default(0)
#  period_type         :string
#  refund_params       :text
#  return_params       :text
#  total_amount        :integer          default(0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  item_id             :integer
#
# Indexes
#
#  index_payments_on_item_id    (item_id)
#  index_payments_on_item_type  (item_type)
#
FactoryBot.define do
  factory :payment do
    
  end
end
