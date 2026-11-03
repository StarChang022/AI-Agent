class ApplicationMailer < ActionMailer::Base
  
  helper_method :current_system_setting

  #default from: "#{SystemSetting.first&.name} <#{ENV['mailgun_user_name']}>"
  default from: "#{SystemSetting.first&.name} <#{ENV['gmail_user_name']}>"

  layout 'mailer'

  def notify(email)
    mail(to: email, subject: "notify")
  end

  private

  def current_system_setting
    @current_system_setting ||= SystemSetting.first
  end

end
