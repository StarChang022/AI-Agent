class Category < ApplicationRecord
  # 類別。一家公司一組；kind 區分支出 / 收入兩種：
  # - expense：建立公司時由 CategorySeeder 塞起始資料；可選為支出 / 代墊款的類別
  # - income：建立公司時塞 4 筆草稿（銷售、服務、利息、其他收入）；可選為收入的類別
  # 兩種不互通：支出下拉只拿 expense、收入下拉只拿 income。預算只綁 expense。
  # 類別可改名、可停用（is_archived=true）；不可刪除、不可改 kind。
  # 停用後不出現在新增下拉；歷史記錄仍顯示原名。

  KINDS = %w[expense income].freeze

  belongs_to :company
  has_many :budgets,          dependent: :restrict_with_error
  has_many :budget_templates, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 50 }
  # name 於同一 (company_id, kind) 內 case-insensitive 唯一；
  # 支出與收入可同名（例如兩邊都有「其他」）。
  validates :name, uniqueness: { scope: [ :company_id, :kind ], case_sensitive: false }
  validates :account_code, length: { maximum: 20 }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind, inclusion: { in: KINDS }

  before_validation :normalize_name

  scope :active,   -> { where(is_archived: false).order(:sort_order, :id) }
  scope :archived, -> { where(is_archived: true).order(:sort_order, :id) }
  scope :of_kind,  ->(kind) { where(kind: kind) }

  private

  def normalize_name
    self.name = name.to_s.strip if name.present?
  end
end
