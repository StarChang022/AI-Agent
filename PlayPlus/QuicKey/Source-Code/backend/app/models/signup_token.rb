class SignupToken < ApplicationRecord
  # 註冊 email 驗證 token；30 分鐘 TTL、單次使用。
  # 隨 token 一起攜帶密碼（bcrypt digest）與公司基本資訊，signup_complete 時
  # 直接從 token 取出建立 User + Company，期間使用者不會再被要求輸入任何資料。
  # 每次 generate_for 會把該 email 未消耗的舊 token 一併失效。
  TTL = 30.minutes

  enum :provider, { email: "email", google: "google" }, prefix: :provider

  scope :active, -> {
    where(consumed_at: nil).where("expires_at > ?", Time.current)
  }

  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  # 建立新 token；先把該 email 未消耗的舊 token 全數過期。
  # 密碼即時 hash，不留明文；公司資訊原樣存，signup_complete 建 Company 時再驗。
  # 回傳 [record, raw_token]；raw_token 只在此刻可得（塞進 email 連結）。
  def self.generate_for(email:, password:, company_type:, company_name:, tax_id: nil, provider: "email")
    normalized_email = email.to_s.downcase.strip
    raw              = SecureRandom.urlsafe_base64(32)

    transaction do
      where(email: normalized_email, consumed_at: nil)
        .update_all(expires_at: Time.current)

      record = create!(
        email:           normalized_email,
        provider:        provider,
        token_digest:    Digest::SHA256.hexdigest(raw),
        expires_at:      TTL.from_now,
        password_digest: BCrypt::Password.create(password),
        company_type:    company_type,
        company_name:    company_name,
        tax_id:          tax_id.to_s.strip.presence
      )

      [ record, raw ]
    end
  end

  def self.find_valid_by_raw(raw)
    return nil if raw.blank?
    active.find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end
end
