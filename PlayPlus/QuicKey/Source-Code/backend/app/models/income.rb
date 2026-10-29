class Income < ApplicationRecord
  # 已開立收入（docs/資料模型.md §2.6）。欄位與 Expense（§2.2）對應，差異：
  # - customer 必填（對應 Expense.vendor）
  # - 收款狀態：collection_status / collected_at（對應 Expense.payout_status / paid_at）
  # - 類別必為 kind='income'（§3.4）
  # items / attachments 以 jsonb 內嵌陣列儲存。

  DOCUMENT_TYPES       = %w[invoice receipt].freeze
  TAX_RATES            = %w[business_5 exempt_0].freeze
  COLLECTION_STATUSES  = %w[uncollected collected].freeze

  belongs_to :company
  belongs_to :category
  belongs_to :created_by, class_name: "User"

  validates :document_type,     inclusion: { in: DOCUMENT_TYPES }
  validates :tax_rate,          inclusion: { in: TAX_RATES }
  validates :collection_status, inclusion: { in: COLLECTION_STATUSES }
  validates :customer, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date,   presence: true

  validate :category_belongs_to_same_company
  validate :category_kind_is_income
  validate :attachments_within_limits
  validate :tax_id_required_for_invoice
  validate :tax_id_format

  scope :uncollected, -> { where(collection_status: "uncollected") }
  scope :collected,   -> { where(collection_status: "collected") }

  # 軟刪：kept 一般列表 / discarded 垃圾桶。不加 default_scope，由 controller 明確選擇。
  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

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

  private

  # 跨公司引用是多租戶隔離漏洞——守門（比照 Expense）。
  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
  end

  # 收入必綁 kind='income' 的類別。若 Category 尚未儲存可能 nil，由 presence/belongs_to 先擋。
  def category_kind_is_income
    return if category.nil?
    errors.add(:category_id, "必須為收入類別") unless category.kind == "income"
  end

  # 憑證張數 / MIME / 單檔大小守門（比照 Expense；attachments 是 jsonb 陣列）。
  def attachments_within_limits
    data_urls = Array(attachments).map do |a|
      a.is_a?(Hash) ? (a["data_url"] || a[:data_url]) : nil
    end.compact
    ReceiptAttachmentValidation.apply(self, :attachments, data_urls)
  end

  # 發票須有買方統編；收據選填（比照 Expense tax_id_required_for_invoice）。
  def tax_id_required_for_invoice
    return unless document_type == "invoice"
    errors.add(:tax_id, "發票須填買方統編") if tax_id.blank?
  end

  # 有填就要是 8 碼數字（發票、收據共用）。
  def tax_id_format
    return if tax_id.blank?
    errors.add(:tax_id, "統編應為 8 碼數字") unless tax_id.to_s.match?(/\A\d{8}\z/)
  end
end
