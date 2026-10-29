class UserMailer < ApplicationMailer
  # 忘記密碼寄信。
  #
  # MVP-stub 期：development 環境已設 delivery_method = :test（見
  # config/environments/development.rb），mail() 不會真的呼叫 SMTP；
  # dev 只需從 log 撈 reset URL 貼到瀏覽器驗證流程。
  # TODO(stage-b-9-smtp): 接 SMTP 後恢復真實寄信，移除 log。
  def password_reset(user, raw_token)
    @user      = user
    @reset_url = "#{Rails.configuration.frontend_base_url}/reset-password?token=#{raw_token}"

    Rails.logger.info "[MVP-stub] Password reset URL for #{user.email}: #{@reset_url}"

    mail(to: user.email, subject: "[Quickey] 重設密碼連結")
  end

  # 註冊 email 驗證。收信人尚未成為 User，故只用 email string。
  # MVP-stub 期同 password_reset：dev 環境不會真的送 SMTP，只從 log 撈連結。
  def signup_verification(email, raw_token)
    @email     = email
    @verify_url = "#{Rails.configuration.frontend_base_url}/signup/complete?token=#{raw_token}"

    Rails.logger.info "[MVP-stub] Signup verification URL for #{email}: #{@verify_url}"

    mail(to: email, subject: "[Quickey] 驗證你的 Email 以完成註冊")
  end

  # 員工邀請信。收信人尚未成為 User；`invitation.name` 是 admin 填的顯示名稱。
  # MVP-stub 期同上：dev 環境從 log 撈連結。
  def invitation(invitation, raw_token)
    @invitation = invitation
    @invitee_name = invitation.name
    @company_name = invitation.company.name
    @accept_url = "#{Rails.configuration.frontend_base_url}/invite/accept?token=#{raw_token}"

    Rails.logger.info "[MVP-stub] Invitation URL for #{invitation.email}: #{@accept_url}"

    mail(to: invitation.email, subject: "[Quickey] #{@company_name} 邀請你加入")
  end
end
