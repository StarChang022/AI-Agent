class Company < ApplicationRecord
  # 方案與員工人數上限（不含管理員；使用中＋邀請中都算）。docs/資料模型.md §3.1「方案上限」。
  PLANS = %w[free team enterprise].freeze
  MEMBER_LIMITS = { "free" => 0, "team" => 5, "enterprise" => 10 }.freeze

  has_many :users, dependent: :restrict_with_error
  has_many :invitations,      dependent: :destroy
  has_many :categories,       dependent: :destroy
  has_many :budgets,          dependent: :destroy
  has_many :budget_templates, dependent: :destroy
  has_many :reimbursements,   dependent: :destroy
  has_many :expenses,         dependent: :destroy
  has_many :incomes,          dependent: :destroy
  has_many :transfers,        dependent: :destroy # 排在支出之後：手續費支出指向移轉
  has_many :recurring_templates, dependent: :destroy
  has_many :accounts,         dependent: :destroy # 排在收支、範本之後：有引用的帳戶不能先刪
  has_many :notifications,    dependent: :destroy
  has_many :audit_logs,       dependent: :destroy
  has_many :data_exports,     dependent: :destroy
  has_many :payout_day_change_logs, dependent: :destroy

  after_create_commit :seed_default_categories

  # 圖檔儲存空間（Byte）：所有紀錄（含垃圾桶與代墊款）使用的圖檔加總，共用檔只算一次，
  # 不含暫存檔（docs/資料模型.md §2.4）。用量畫面與上限另開卡。
  def storage_bytes
    AttachmentFiles.storage_bytes(self)
  end

  enum :company_type, {
    limited:     "limited",      # 有限公司
    corporation: "corporation",  # 股份有限公司
    studio:      "studio",       # 工作室
    individual:  "individual"    # 個人
  }, prefix: :company_type

  validates :name, presence: true, length: { maximum: 100 }
  validates :company_type, presence: true
  validates :plan, inclusion: { in: PLANS }
  validates :payout_day,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 },
            allow_nil: true
  validate :tax_id_format_and_checksum, if: -> { tax_id.present? }

  before_save :normalize_tax_id

  # 公司有沒有任何帳戶（不含垃圾桶）；沒有時不能新增收支、範本、匯入、通過請款（PRD 規則 20）。
  def any_account?
    accounts.kept.exists?
  end

  # 員工人數上限，依方案決定。
  def member_limit
    MEMBER_LIMITS.fetch(plan)
  end

  # 已使用名額 = 使用中／邀請中的員工 + 尚在有效期的邀請（未接受、未撤回、未過期）。
  # 不含管理員與停用的員工。被邀請未接受的以 Invitation.active 為準。
  def members_used
    users.role_employee.where(status: %w[active invited]).count + invitations.active.count
  end

  # 已達或超過上限就不能再邀請；超過上限時不停用既有員工。
  def members_at_limit?
    members_used >= member_limit
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
