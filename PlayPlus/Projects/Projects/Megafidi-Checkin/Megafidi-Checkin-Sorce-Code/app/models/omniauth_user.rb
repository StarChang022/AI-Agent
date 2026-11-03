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
class OmniauthUser < ApplicationRecord

  belongs_to :user

  validates_presence_of :uid, :provider
  validates_uniqueness_of :uid, :scope => :provider, conditions: -> {without_deleted}

  def self.find_for_oauth(auth)
    find_or_create_by(uid: auth.uid, provider: auth.provider)
  end

end
