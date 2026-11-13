class User < ApplicationRecord
  # bcrypt 密碼雜湊；提供 authenticate(password)、password= 等方法。
  # validations: false 讓密碼可為 nil（未來 Google 註冊路徑），改在下方自訂驗證。
  has_secure_password validations: false

  # 關聯
  belongs_to :company
  has_many :password_reset_tokens, dependent: :destroy
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :nullify
  # 本人提交的代墊款請款（前台「我的請款」查詢；擁有者隔離）
  has_many :reimbursements, foreign_key: :employee_id, dependent: :restrict_with_error, inverse_of: :employee
  # 本人收到的站內通知（鈴鐺 / 通知中心）
  has_many :notifications, dependent: :destroy

  # 列舉：Rails 8 用 String-backed enum。prefix 讓查詢時要用 user.role_superadmin?
  # 而非 user.superadmin?，避免與其他 model 命名衝突。
  enum :role,   { admin: "admin", employee: "employee" }, prefix: :role
  enum :status, { active: "active", invited: "invited", suspended: "suspended" }, prefix: :status

  # 驗證
  validates :email,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  # 剛註冊的管理員姓名空白，到歡迎設定頁才補（前端 router 依此導向 /admin/setup）。
  # 所以建立時不檢查；之後只在改姓名時必填，改密碼、導覽狀態等其他欄位不受影響。
  validates :name, presence: true, on: :update, if: :name_changed?
  validates :password_digest, presence: true, unless: :external_auth?
  validates :password,
    length: { minimum: 8 },
    if: -> { password.present? }

  # 未來若 User 有 google_id 等外部認證欄位，改為判斷這些欄位是否存在。
  # 現階段永遠 false，代表所有 User 都必須有密碼。
  def external_auth?
    false
  end

  # Email 一律小寫、去空白（避免 "Foo@Bar.com" 與 "foo@bar.com" 被視為不同帳號）
  before_save :normalize_email

  # 上一次使用的帳戶：這位使用者最新建立、不在垃圾桶的一筆收支（支出、收入共用）目前的帳戶。
  # 手動新增、Excel 匯入、代墊款核准都會建立收支，所以不另外記；系統產生的固定紀錄、手續費不算。
  # 帳戶已刪除時回 nil。
  def last_used_account
    latest = [ Expense, Income ]
      .filter_map { |model| model.kept.user_entered.where(created_by_id: id).order(created_at: :desc).pick(:account_id, :created_at) }
      .max_by(&:last)
    latest && company.accounts.kept.find_by(id: latest.first)
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
