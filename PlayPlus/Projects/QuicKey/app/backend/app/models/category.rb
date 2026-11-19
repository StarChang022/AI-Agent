class Category < ApplicationRecord
  # 類別。一家公司一組；kind 區分支出 / 收入兩種：
  # - expense：建立公司時由 CategorySeeder 塞起始資料；可選為支出 / 代墊款的類別
  # - income：建立公司時塞 4 筆草稿（銷售、服務、利息、其他收入）；可選為收入的類別
  # 兩種不互通：支出下拉只拿 expense、收入下拉只拿 income。預算只綁 expense。
  # 類別可改名、可停用（is_archived=true）；不可改 kind。
  # 停用後不出現在新增下拉；歷史記錄仍顯示原名。
  # 刪除先進垃圾桶（PRD 第 18 條），和停用互不影響：進出垃圾桶不動 is_archived。

  KINDS = %w[expense income].freeze
  # 系統保留類別：可改名，不可停用、不可刪除（docs/資料模型.md §3.4）。
  TRANSFER_FEE_KEY = "transfer_fee".freeze

  # 永久刪除檢查：要擋的引用來源都登記在這裡。counts 收類別 id 陣列，回 { 類別 id => 筆數 }。
  # 含垃圾桶內的紀錄與歷史、垃圾桶內的範本；預算只算過往期間，當期與未來的預算進垃圾桶時已清除。
  USAGE_SOURCES = {
    expenses:            { label: "支出",         counts: ->(ids) { Expense.where(category_id: ids).group(:category_id).count } },
    incomes:             { label: "收入",         counts: ->(ids) { Income.where(category_id: ids).group(:category_id).count } },
    reimbursements:      { label: "代墊款",       counts: ->(ids) { Reimbursement.where(category_id: ids).group(:category_id).count } },
    recurring_templates: { label: "固定收支範本", counts: ->(ids) { RecurringTemplate.where(category_id: ids).group(:category_id).count } },
    budgets:             { label: "過往預算",     counts: ->(ids) { Budget.where(category_id: ids, period_end: ...Date.current).group(:category_id).count } }
  }.freeze

  belongs_to :company
  has_many :budgets,             dependent: :restrict_with_error
  has_many :budget_templates,    dependent: :restrict_with_error
  has_many :recurring_templates, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 50 }
  # name 於同一 (company_id, kind) 內 case-insensitive 唯一；
  # 支出與收入可同名（例如兩邊都有「其他」）。
  validates :name, uniqueness: { scope: [ :company_id, :kind ], case_sensitive: false }
  validates :account_code, length: { maximum: 20 }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind, inclusion: { in: KINDS }

  before_validation :normalize_name

  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }
  scope :active,    -> { kept.where(is_archived: false).order(:sort_order, :id) }
  scope :archived,  -> { kept.where(is_archived: true).order(:sort_order, :id) }
  scope :of_kind,   ->(kind) { where(kind: kind) }
  # 寫入紀錄時可選的類別。編輯時帶紀錄目前的類別：類別沒換就不擋，表單才能把垃圾桶內的類別原樣送回。
  scope :selectable, ->(current_id = nil) { kept.or(where(id: current_id)) }

  # 一次算多個類別的引用筆數：{ 類別 id => { expenses: 3, incomes: 0, ... } }，避免列表每筆都查。
  def self.usage_counts(ids)
    counts = USAGE_SOURCES.transform_values { |source| source[:counts].call(ids) }
    ids.index_with { |id| counts.transform_values { |by_category| by_category.fetch(id, 0) } }
  end

  # 引用筆數的白話說明，例：「3 筆支出、1 筆固定收支範本」。
  def self.describe_usage(counts)
    counts.select { |_, count| count.positive? }
      .map { |key, count| "#{count} 筆#{USAGE_SOURCES.fetch(key)[:label]}" }.join("、")
  end

  # 使用這些類別的進行中範本：{ 類別 id => [範本] }。垃圾桶內與歷史的範本不算。
  def self.active_templates(ids)
    RecurringTemplate.kept.where(category_id: ids).reject(&:expired?).group_by(&:category_id)
  end

  def usage_counts
    self.class.usage_counts([ id ]).fetch(id)
  end

  def active_templates
    self.class.active_templates([ id ]).fetch(id, [])
  end

  def system?
    system_key.present?
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

  # 停用、進垃圾桶共用：清除基本預算與當期、未來的預算（period_end >= today），
  # 過往期間的預算保留供歷史查閱。之後不會自動恢復，使用者要重新設定。
  # 每筆清掉的預算寫一筆 delete 稽核，操作人為停用或刪除類別的人；基本預算不寫。
  # 需在類別停用、刪除的交易內呼叫。
  # 從 budgets 關聯撈出的預算已帶著本類別（Rails 自動設定反向關聯），快照取類別名稱不會再查。
  def clear_current_budgets!(by:)
    budgets.where("period_end >= ?", Date.current).each do |budget|
      AuditLog.record!(budget, action: "delete", by: by,
        before: budget.audit_snapshot.merge(via: "category_clear"))
      budget.destroy!
    end
    budget_templates.destroy_all
  end

  # create / purge 寫入 AuditLog 的核心快照。
  def audit_snapshot
    { kind: kind, name: name, account_code: account_code, is_archived: is_archived, sort_order: sort_order }
  end

  private

  def normalize_name
    self.name = name.to_s.strip if name.present?
  end
end
