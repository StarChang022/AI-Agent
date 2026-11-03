# == Schema Information
#
# Table name: system_settings
#
#  id                :integer          not null, primary key
#  address           :string
#  deleted_at        :datetime
#  email             :string
#  line_notify_token :string
#  name              :string
#  phone             :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
FactoryBot.define do
  factory :system_setting do
    
  end
end
