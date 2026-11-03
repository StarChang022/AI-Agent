# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  address                :string
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  county                 :string
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  deleted_at             :datetime
#  district               :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  gender                 :integer
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  name                   :string
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  unlock_token           :string
#  zipcode                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
class User < ApplicationRecord

 # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :confirmable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, :omniauth_providers => [:facebook, :google_oauth2, :line]

  enum gender: {
    male: 0,
    female: 1,
    private_gender: 2
  }

  include EnumName

  def self.from_omniauth(auth, signed_in_resource = nil)
    omniauth_user = OmniauthUser.find_for_oauth(auth)

    user = signed_in_resource ? signed_in_resource : omniauth_user.user

    if user.nil?
      email = auth.info.email

      user = User.find_by(email: email) if email

      if user.nil?
        user = User.new(name: auth.info.name.gsub(/\s+/, '_'),
          email: auth.info.email,
          password: Devise.friendly_token[0,20])
        user.skip_confirmation!
        user.save!
      end
    end

    if omniauth_user.user != user
      omniauth_user.user = user
      omniauth_user.save!
    end

    user
  end

  def delete_access_token(auth)
    @graph ||= Koala::Facebook::API.new(auth.credentials.token)
    @graph.delete_connections(auth.uid, "permissions")
  end

  # 如果希望不要驗證current password
  def update_with_password(params, *options)
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end

    result = update(params, *options)

    clean_up_passwords
    result
  end

  # 允許用其他key登入
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      #where(conditions.to_h).where(["lower(email) = :value", { :value => login.downcase }]).first
      where(conditions.to_h).where(["lower(email) = :value", { :value => login.downcase }]).first
    elsif conditions.has_key?(:username) || conditions.has_key?(:email)
      where(conditions.to_h).first
    end
  end

  def login=(login)
    @login = login
  end

  def login
    @login || self.email
  end

  def full_address
    "#{county}#{district}#{address}"
  end

end
