# == Schema Information
#
# Table name: period_payments
#
#  id            :integer          not null, primary key
#  deleted_at    :datetime
#  num           :string
#  return_params :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  payment_id    :integer
#
# Indexes
#
#  index_period_payments_on_payment_id  (payment_id)
#
class PeriodPayment < ApplicationRecord

  store :return_params

  belongs_to :payment

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
