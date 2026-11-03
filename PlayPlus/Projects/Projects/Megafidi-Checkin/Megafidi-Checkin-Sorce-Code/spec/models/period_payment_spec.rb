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
require 'rails_helper'

RSpec.describe PeriodPayment, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
