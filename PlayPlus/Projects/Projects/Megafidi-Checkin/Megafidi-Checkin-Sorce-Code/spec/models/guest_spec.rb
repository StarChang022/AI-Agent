# == Schema Information
#
# Table name: guests
#
#  id                :integer          not null, primary key
#  behalf            :string
#  certificate_num   :string
#  company_name      :string
#  deleted_at        :datetime
#  department_name   :string
#  name              :string
#  note              :text
#  phone             :string
#  registration_time :datetime
#  special           :boolean          default(FALSE)
#  status            :integer
#  trophy_num        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  activity_id       :integer
#
# Indexes
#
#  index_guests_on_activity_id  (activity_id)
#
require 'rails_helper'

RSpec.describe Guest, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
