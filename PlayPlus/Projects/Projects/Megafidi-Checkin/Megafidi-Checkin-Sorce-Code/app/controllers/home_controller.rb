class HomeController < ApplicationController
  before_action :authenticate_admin!

  helper_method :activities

  before_action :authenticate_status
  before_action :authenticate_role

  def checkin
    # 暫時設定
  end

  def success
    # 暫時設定
  end

  def login
    # 暫時設定
  end

  private

  def activities
    @activities = Activity.all
  end

  def authenticate_status
    unless current_admin.active?
      flash[:error] = '您的帳號已被停用'
      sign_out current_admin
      redirect_to new_admin_session_path
      return
    end
  end

  def authenticate_role
    unless current_admin.admin?
      flash[:error] = '您沒有權限訪問此頁面'
      redirect_to root_path
      return
    end
  end

  def check_recaptcha_v2
    valid = verify_recaptcha secret_key: ENV['recaptcha_secret_key']

    unless valid
      flash[:error] = t('recaptcha.failed')
      redirect_back(fallback_location: root_path)
      return
    end
  end
end
