class Account < ApplicationRecord
  # 公司的收付帳戶（docs/資料模型.md §2.9）。opening_amount 是起始金額，視為 opening_month
  # 月初的餘額；之後各期的期初、期末由現金流報表依收付款即時計算，不另外存。
  # 刪除一律先進垃圾桶，被任一收支或資金移轉引用的帳戶不可刪除（PRD 規則 18、21）。

  CURRENCY      = "TWD".freeze
  NAME_MAX      = 50
  MAX_AMOUNT    = BigDecimal("9999999999.99")
  OPENING_MONTH_MIN = Date.new(2000, 1, 1)

  # 公司沒有任何帳戶（不含垃圾桶）時，新增收支、固定收支範本、匯入、通過請款的錯誤訊息（PRD 規則 20）。
  NO_ACCOUNTS_MESSAGE = "公司還沒有帳戶，請先到帳戶設定建立".freeze

  # 刪除檢查：要擋刪除的引用來源都登記在這裡。counts 收帳戶 id 陣列，回 { 帳戶 id => 筆數 }。
  # 含垃圾桶內的紀錄與歷史、垃圾桶內的範本，否則它們還原後會指向已刪除的帳戶。
  REFERENCE_SOURCES = {
    expenses: { label: "支出", counts: ->(ids) { Expense.where(account_id: ids).group(:account_id).count } },
    incomes:  { label: "收入", counts: ->(ids) { Income.where(account_id: ids).group(:account_id).count } },
    recurring_templates: { label: "固定收支範本", counts: ->(ids) { RecurringTemplate.where(account_id: ids).group(:account_id).count } },
    transfers: { label: "資金移轉", counts: ->(ids) {
      Transfer.where(from_account_id: ids).group(:from_account_id).count
        .merge(Transfer.where(to_account_id: ids).group(:to_account_id).count) { |_, out, into| out + into }
    } }
  }.freeze

  belongs_to :company
  has_many :expenses, dependent: :restrict_with_exception
  has_many :incomes,  dependent: :restrict_with_exception
  has_many :recurring_templates, dependent: :restrict_with_exception
  has_many :transfers_out, class_name: "Transfer", foreign_key: :from_account_id, dependent: :restrict_with_exception
  has_many :transfers_in,  class_name: "Transfer", foreign_key: :to_account_id,   dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: NAME_MAX }
  validates :name, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :currency, inclusion: { in: [ CURRENCY ] }
  validates :opening_amount, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :opening_month, presence: true
  validate :opening_month_within_range, if: :opening_month_changed?

  before_validation :normalize_name

  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  # 新帳戶：起始金額視為起始月份月初的餘額，起始月份預設當月。
  def self.build_with_opening(company:, name:, opening_amount:, opening_month: nil)
    company.accounts.new(name: name, opening_amount: opening_amount,
                         opening_month: opening_month || Date.current.beginning_of_month)
  end

  def self.opening_month_in_range?(month)
    month.between?(OPENING_MONTH_MIN, Date.current.beginning_of_month)
  end

  # 一次算多個帳戶的引用筆數：{ 帳戶 id => { expenses: 3, incomes: 0 } }，避免列表每筆都查。
  def self.reference_counts(ids)
    counts = REFERENCE_SOURCES.transform_values { |source| source[:counts].call(ids) }
    ids.index_with { |id| counts.transform_values { |by_account| by_account.fetch(id, 0) } }
  end

  # 引用筆數的白話說明，例：「3 筆支出、1 筆收入」。
  def self.describe_references(counts)
    counts.select { |_, count| count.positive? }
      .map { |key, count| "#{count} 筆#{REFERENCE_SOURCES.fetch(key)[:label]}" }.join("、")
  end

  def reference_counts
    self.class.reference_counts([ id ]).fetch(id)
  end

  def discarded?
    deleted_at.present?
  end

  def discard!
    return self if discarded?
    update!(deleted_at: Time.current)
  end

  def restore_from_trash!
    return self unless discarded?
    update!(deleted_at: nil)
  end

  # 起始月份改成 month 時，不計入現金流的已收款、已付款筆數（不含垃圾桶）。
  def outside_cash_flow_counts(month)
    {
      expenses: expenses.kept.settled.where(Expense.cash_date => ...month).count,
      incomes:  incomes.kept.settled.where(Income.cash_date => ...month).count
    }
  end

  # 起始月份改成 month 時會擋下調整的移轉：筆數與最早日期。垃圾桶內的移轉不擋，還原時才檢查。
  def blocking_transfers(month)
    scope = Transfer.kept.involving(id).where(transfer_date: ...month)
    { count: scope.count, earliest: scope.minimum(:transfer_date) }
  end

  # create / purge 寫入 AuditLog 的核心快照。
  def audit_snapshot
    {
      name:           name,
      currency:       currency,
      opening_amount: opening_amount&.to_f,
      opening_month:  opening_month&.iso8601
    }
  end

  private

  def opening_month_within_range
    return if opening_month.nil? || self.class.opening_month_in_range?(opening_month)
    errors.add(:opening_month, "需介於 2000 年 1 月至當月")
  end

  def normalize_name
    self.name = name.to_s.strip if name.present?
  end
end
