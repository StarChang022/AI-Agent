class Company < ApplicationRecord
  # 一家公司員工上限（含已接受 + 未接受邀請）；PRD 免費方案硬性上限。
  MEMBER_LIMIT = 10

  has_many :users, dependent: :restrict_with_error
  has_many :invitations,      dependent: :destroy
  has_many :categories,       dependent: :destroy
  has_many :budgets,          dependent: :destroy
  has_many :budget_templates, dependent: :destroy
  has_many :reimbursements,   dependent: :destroy
  has_many :expenses,         dependent: :destroy
  has_many :incomes,          dependent: :destroy
  has_many :notifications,    dependent: :destroy
  has_many :audit_logs,       dependent: :destroy
  has_many :payout_day_change_logs, dependent: :destroy

  after_create_commit :seed_default_categories

  enum :company_type, {
    limited:     "limited",      # 有限公司
    corporation: "corporation",  # 股份有限公司
    studio:      "studio",       # 工作室
    individual:  "individual"    # 個人
  }, prefix: :company_type

  validates :name, presence: true, length: { maximum: 100 }
  validates :company_type, presence: true
  validates :payout_day,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 },
            allow_nil: true
  validate :tax_id_format_and_checksum, if: -> { tax_id.present? }

  before_save :normalize_tax_id

  # 已使用名額 = users 全數 + 尚在有效期的邀請（未接受、未撤回、未過期）。
  # active User 已計入 users；被邀請未接受的以 Invitation.active 為準。
  def members_used
    users.count + invitations.active.count
  end

  def members_at_limit?
    members_used >= MEMBER_LIMIT
  end

  private

  def seed_default_categories
    CategorySeeder.seed!(self)
  end

  def normalize_tax_id
    self.tax_id = tax_id.to_s.strip.presence
  end

  # 台灣統編檢核：8 碼數字 + 加權檢核（第 7 位為 7 時特殊處理）
  # 權重：1 2 1 2 1 2 4 1；每位相乘後個位+十位加總 → 總和 % 10 == 0 為合法
  # 第 7 位為 7 時，若總和 % 10 != 0，允許加 1 後再檢查
  def tax_id_format_and_checksum
    unless tax_id.match?(/\A\d{8}\z/)
      errors.add(:tax_id, "must be 8 digits")
      return
    end

    weights = [ 1, 2, 1, 2, 1, 2, 4, 1 ]
    digits  = tax_id.chars.map(&:to_i)
    sum = digits.each_with_index.sum do |d, i|
      product = d * weights[i]
      product / 10 + product % 10
    end

    valid = (sum % 10).zero? || (digits[6] == 7 && ((sum + 1) % 10).zero?)
    errors.add(:tax_id, "invalid Taiwan tax ID checksum") unless valid
  end
end
