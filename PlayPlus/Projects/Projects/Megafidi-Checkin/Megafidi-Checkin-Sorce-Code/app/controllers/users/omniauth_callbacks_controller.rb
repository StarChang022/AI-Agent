# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # You should configure your model like this:
  # devise :omniauthable, omniauth_providers: [:twitter]
  def facebook
    handle_auth("Facebook")
  end

  def google_oauth2
    handle_auth("Google")
  end

  def line
    handle_auth("Line")
  end

  def failure
    redirect_to new_user_session_path, alert: "無法獲得驗證！"
  end

  private

  def auth
    request.env["omniauth.auth"]
  end

  def handle_auth(kind)
    @user = User.from_omniauth(request.env["omniauth.auth"], current_user)
    if @user.persisted?
      sign_in_and_redirect @user, :event => :authentication
      set_flash_message(:notice, :success, :kind => kind) if is_navigational_format?
    else

      if @user.email.nil?
        @user.delete_access_token(auth) if kind == "Facebook"
        redirect_to new_user_registration_url, alert: "需要您同意 Email 授權唷！"
      else
        session["devise.#{kind.downcase}_data"] = request.env["omniauth.auth"]
        redirect_to new_user_registration_url
      end
    end
  end

  # You should also create an action method in this controller like this:
  # def twitter
  # end

  # More info at:
  # https://github.com/plataformatec/devise#omniauth

  # GET|POST /resource/auth/twitter
  # def passthru
  #   super
  # end

  # GET|POST /users/auth/twitter/callback
  # def failure
  #   super
  # end

  # protected

  # The path used when OmniAuth fails
  # def after_omniauth_failure_path_for(scope)
  #   super(scope)
  # end
end
