class PasswordResetToken < ApplicationRecord
  belongs_to :user

  # 30 分鐘 TTL；成功 reset 後標 used_at。
  TTL = 30.minutes

  scope :active, -> {
    where(used_at: nil).where("expires_at > ?", Time.current)
  }

  def used?
    used_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  # 為指定 user 產生新 token。回傳 [record, raw_token]。
  # raw_token 只在此刻拿得到（用來塞 email）；DB 只存 SHA256 digest。
  def self.generate_for(user)
    raw = SecureRandom.urlsafe_base64(32)
    record = create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(raw),
      expires_at: TTL.from_now
    )
    [ record, raw ]
  end

  # 用 user 送來的 raw token 找對應「還沒過期、還沒用過」的 record。
  def self.find_valid_by_raw(raw)
    return nil if raw.blank?
    active.find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end
end
