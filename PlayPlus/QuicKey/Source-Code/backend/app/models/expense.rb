class Expense < ApplicationRecord
  # 已成立支出（docs/資料模型.md §2.2）。全部進統一支出列表。
  # source='general'（行政直接登錄）本次做；source='reimbursement'（核准代墊款轉入）
  # 的連動留待後續模組。items / attachments 以 jsonb 內嵌陣列儲存。

  SOURCES         = %w[general reimbursement].freeze
  DOCUMENT_TYPES  = %w[invoice receipt].freeze
  TAX_RATES       = %w[business_5 exempt_0].freeze
  PAYOUT_STATUSES = %w[pending paid].freeze

  belongs_to :company
  belongs_to :category
  belongs_to :created_by, class_name: "User"
  belongs_to :paid_by, class_name: "User", optional: true

  validates :source,        inclusion: { in: SOURCES }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validates :tax_rate,      inclusion: { in: TAX_RATES }
  validates :payout_status, inclusion: { in: PAYOUT_STATUSES }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date,   presence: true

  validate :category_belongs_to_same_company
  validate :attachments_within_limits
  validate :tax_id_required_for_invoice
  validate :tax_id_format

  scope :general,            -> { where(source: "general") }
  scope :from_reimbursement, -> { where(source: "reimbursement") }
  scope :pending,            -> { where(payout_status: "pending") }
  scope :paid,               -> { where(payout_status: "paid") }

  # 軟刪除：kept 為一般列表、discarded 為垃圾桶。預設不加 default_scope，
  # 由 controller 明確選擇，以免 Reimbursement/Budget 等 cross-model query 誤漏資料。
  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  def discarded?
    deleted_at.present?
  end

  # 軟刪：記下時間；若已刪則保持原時間不覆蓋。
  def discard!
    return self if discarded?
    update!(deleted_at: Time.current)
  end

  # 還原：清掉 deleted_at。
  def restore_from_trash!
    return self unless discarded?
    update!(deleted_at: nil)
  end

  private

  # 跨公司引用是多租戶隔離漏洞——守門（比照 Budget#category_belongs_to_same_company）。
  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
  end

  # 憑證張數 / MIME / 單檔大小守門（前端已擋，後端補一層避免繞過 API 直接送）。
  # attachments 是 jsonb 陣列 [{data_url, filename, mime_type}, ...]；只驗 data_url。
  def attachments_within_limits
    data_urls = Array(attachments).map do |a|
      a.is_a?(Hash) ? (a["data_url"] || a[:data_url]) : nil
    end.compact
    ReceiptAttachmentValidation.apply(self, :attachments, data_urls)
  end

  # 發票須有賣方統編；收據選填（小攤販無統編）。對齊前端 ExpenseFormView validate。
  def tax_id_required_for_invoice
    return unless document_type == "invoice"
    errors.add(:tax_id, "發票須填賣方統編") if tax_id.blank?
  end

  # 有填就要是 8 碼數字（發票、收據共用）。
  def tax_id_format
    return if tax_id.blank?
    errors.add(:tax_id, "統編應為 8 碼數字") unless tax_id.to_s.match?(/\A\d{8}\z/)
  end
end
