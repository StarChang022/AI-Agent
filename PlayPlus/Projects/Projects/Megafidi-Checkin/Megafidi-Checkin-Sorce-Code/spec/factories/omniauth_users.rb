# == Schema Information
#
# Table name: omniauth_users
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  provider   :string
#  token      :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#
# Indexes
#
#  index_omniauth_users_on_provider  (provider)
#  index_omniauth_users_on_user_id   (user_id)
#
FactoryBot.define do
  factory :omniauth_user do
    
  end
end
