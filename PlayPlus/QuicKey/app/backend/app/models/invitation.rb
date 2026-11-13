class Invitation < ApplicationRecord
  # 員工邀請 token。
  #
  # 一封邀請＝ admin 於 UsersView 送出的 email + 姓名組合。
  # 3 天 TTL；未過期、未接受、未撤回三條件全滿足才算有效。
  # 撤回採軟刪（設 revoked_at），既有連結進 Accept 頁時能顯示對應錯誤。
  # 接受後仍保留紀錄供未來「邀請歷史」查詢。

  TTL = 3.days
  # 同一筆邀請重新寄送的最短間隔。
  RESEND_INTERVAL = 60.seconds

  belongs_to :company
  belongs_to :invited_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :normalize_email

  # 有效邀請：未接受、未撤回、未過期。
  scope :active, -> {
    where(accepted_at: nil, revoked_at: nil)
      .where("expires_at > ?", Time.current)
  }

  # 列表預設顯示：未接受、未撤回（含已過期，管理員可重新寄送或刪除）。
  scope :listed, -> { where(accepted_at: nil, revoked_at: nil) }

  # 為指定 (company, email, name) 產生新邀請；先把該 company + email 未接受未撤回的
  # 舊邀請（含已過期）一併撤回，避免同 email 有多封有效邀請、列表重複出現。
  # 回傳 [record, raw_token]；raw_token 只在此刻可得（塞進 email 連結）。
  def self.generate_for(company:, email:, name:, invited_by: nil)
    normalized = email.to_s.downcase.strip
    raw        = SecureRandom.urlsafe_base64(32)
    now        = Time.current

    transaction do
      where(company_id: company.id, email: normalized, accepted_at: nil, revoked_at: nil)
        .update_all(revoked_at: now, updated_at: now)

      record = create!(
        company:      company,
        invited_by:   invited_by,
        email:        normalized,
        name:         name,
        token_digest: Digest::SHA256.hexdigest(raw),
        expires_at:   now + TTL,
        last_sent_at: now
      )

      [ record, raw ]
    end
  end

  # 重新寄送：換新 token（舊連結作廢）、有效期限重算、記錄寄出時間。回傳新的 raw token。
  def regenerate_token!
    raw = SecureRandom.urlsafe_base64(32)
    now = Time.current
    update!(token_digest: Digest::SHA256.hexdigest(raw), expires_at: now + TTL, last_sent_at: now)
    raw
  end

  # 距上次寄出不到 RESEND_INTERVAL；回傳還要等幾秒（0 = 可以寄）。
  def resend_wait_seconds
    [ (last_sent_at + RESEND_INTERVAL - Time.current).ceil, 0 ].max
  end

  def self.find_by_raw(raw)
    return nil if raw.blank?
    find_by(token_digest: Digest::SHA256.hexdigest(raw))
  end

  # Accept 頁用來分類錯誤訊息。
  def status
    return "accepted" if accepted_at.present?
    return "revoked"  if revoked_at.present?
    return "expired"  if expires_at <= Time.current
    "valid"
  end

  def active?
    status == "valid"
  end

  def accepted?
    accepted_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end
end
