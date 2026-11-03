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
class Payment < ApplicationRecord

  store :payment_params
  store :payment_info_params
  store :return_params
  store :refund_params

  belongs_to :item, polymorphic: true, optional: true

  has_many :period_payments, dependent: :destroy

  enum payment_type: {
    aio_credit: 1,
    aio_credit_installment: 2,
    aio_credit_period: 3,
    line_pay: 4,
    aio_atm: 5,
  }

  validates :period_type, inclusion: { in: ['Y', 'M', 'D'] }, allow_nil: true

  after_create do
    _num = "#{SecureRandom.hex(8)}#{id.to_s.rjust(2,"0")}"
    self.update_column(:num, _num)
  end


  def item_name
    "item_name"
  end

  def trade_desc
    "trade_desc"
  end

  def run
    if success?
      # 執行動作
    else
      # 執行例外
    end
  end

  def success?
    return_params.dig('rtn_code') == "1" || return_params.dig('status') == "S" || return_params.dig('return_code') == "0000"
  end

end
