module Api
  # 認證相關 endpoint。signup / login / password 相關為 public，
  # 只有 logout 需要 JWT。
  class AuthController < ApplicationController
    skip_before_action :authenticate!,
      only: %i[signup_request signup_verify signup_complete login forgot_password reset_password]

    # POST /api/auth/signup/request
    # 收 email + 密碼 + 公司資訊：一律回 202（防止 email 枚舉）。
    # email 已註冊過 → 靜默不寄信；否則 payload 寫進 SignupToken 並寄驗證信，
    # 使用者點信中連結後 signup_complete 直接從 token 建立 User + Company，
    # 不會再被要求輸入任何資料。
    def signup_request
      email = normalize_email(params[:email])

      if email.present? && User.where(email: email).none?
        _record, raw_token = SignupToken.generate_for(
          email:        email,
          password:     params[:password].to_s,
          company_type: params[:company_type],
          company_name: params[:company_name],
          tax_id:       params[:tax_id]
        )
        UserMailer.signup_verification(email, raw_token).deliver_now
      end

      render json: { message: "If the email is available, a verification link has been sent." },
             status: :accepted
    end

    # GET /api/auth/signup/verify?token=xxx
    # 前端點驗證信連結進註冊頁時呼叫；只驗證 token 有效性、不消耗。
    def signup_verify
      token_record = SignupToken.find_valid_by_raw(params[:token])
      return render_invalid_signup_token if token_record.nil?

      token_record.update!(verified_at: Time.current) if token_record.verified_at.nil?

      render json: {
        email:    token_record.email,
        provider: token_record.provider
      }, status: :ok
    end

    # POST /api/auth/signup/complete
    # 僅收 token，payload 全從 SignupToken 取出。
    # transaction 內建 Company + admin User + consume token → 回 JWT 自動登入。
    # 姓名於歡迎設定頁補填，所以 User.name 先存空字串。
    def signup_complete
      token_record = SignupToken.find_valid_by_raw(params[:token])
      return render_invalid_signup_token if token_record.nil?

      user    = nil
      company = nil

      ActiveRecord::Base.transaction do
        company = Company.create!(
          name:         token_record.company_name,
          company_type: token_record.company_type,
          tax_id:       token_record.tax_id
        )
        user = User.create!(
          email:           token_record.email,
          password_digest: token_record.password_digest,
          name:            "",
          role:            "admin",
          status:          "active",
          company:         company
        )
        token_record.update!(consumed_at: Time.current)
      end

      record_login!(user)
      render json: {
        user:    serialize_user(user),
        company: serialize_company(company),
        token:   issue_token(user)
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # POST /api/auth/login
    def login
      user = User.find_by(email: normalize_email(params[:email]))

      if user&.authenticate(params[:password])
        record_login!(user)
        render json: {
          user:    serialize_user(user),
          company: serialize_company(user.company),
          token:   issue_token(user)
        }, status: :ok
      else
        render json: { error: "invalid_credentials" }, status: :unauthorized
      end
    end

    # POST /api/auth/logout
    def logout
      # Stateless JWT：後端不需要做任何事，前端負責清 token。
      head :no_content
    end

    # POST /api/auth/password/forgot
    # 不論 email 是否存在，一律回 202；避免帳號枚舉。
    def forgot_password
      user = User.find_by(email: normalize_email(params[:email]))

      if user.present?
        _record, raw_token = PasswordResetToken.generate_for(user)
        # MVP：deliver_now 避免依賴 Solid Queue worker；delivery_method = :test
        # 在 dev env 下不會真的呼叫 SMTP，只把郵件放進 ActionMailer::Base.deliveries。
        UserMailer.password_reset(user, raw_token).deliver_now
      end

      render json: { message: "If the email exists, a reset link has been sent." },
             status: :accepted
    end

    # POST /api/auth/password/reset
    def reset_password
      token_record = PasswordResetToken.find_valid_by_raw(params[:token])
      return render_invalid_reset_token if token_record.nil?

      user = token_record.user
      user.password = params[:new_password]

      if user.save
        token_record.update!(used_at: Time.current)
        record_login!(user)
        render json: {
          user:    serialize_user(user),
          company: serialize_company(user.company),
          token:   issue_token(user)
        }, status: :ok
      else
        render json: validation_error(user), status: :unprocessable_content
      end
    end

    # POST /api/auth/password/change
    # 已登入使用者於「修改密碼」對話框呼叫；先比對舊密碼 hash 再寫入新密碼。
    def change_password
      unless current_user.authenticate(params[:old_password])
        return render json: { error: "invalid_old_password" }, status: :unauthorized
      end

      current_user.password = params[:new_password]
      if current_user.save
        head :no_content
      else
        render json: validation_error(current_user), status: :unprocessable_content
      end
    end

    private

    def normalize_email(raw)
      raw.to_s.downcase.strip
    end

    def issue_token(user)
      JwtService.encode(user_id: user.id)
    end

    def record_login!(user)
      user.update_column(:last_login_at, Time.current)
    end

    def serialize_user(user)
      user.as_json(only: %i[id email name role status company_id onboarding_completed_at])
    end

    def serialize_company(company)
      company.as_json(only: %i[id name company_type tax_id plan])
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_invalid_signup_token
      render json: { error: "invalid_or_expired_signup_token" }, status: :bad_request
    end

    def render_invalid_reset_token
      render json: { error: "invalid_or_expired_token" }, status: :bad_request
    end
  end
end
