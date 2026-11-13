class Expense < ApplicationRecord
  include AccountLedgerEntry

  # 已成立支出（docs/資料模型.md §2.2）。全部進統一支出列表。
  # source='general'（行政直接登錄）本次做；source='reimbursement'（核准代墊款轉入）
  # 的連動留待後續模組；source='transfer_fee' 由資金移轉產生，只能經由移轉異動。
  # items 以 jsonb 內嵌陣列儲存；圖檔為實體檔案（AttachmentFiles）。

  SOURCES         = %w[general reimbursement transfer_fee].freeze
  DOCUMENT_TYPES  = %w[invoice receipt].freeze
  TAX_RATES       = %w[business_5 exempt_0].freeze
  PAYOUT_STATUSES = %w[pending paid].freeze

  belongs_to :company
  belongs_to :category
  belongs_to :created_by, class_name: "User"
  belongs_to :paid_by, class_name: "User", optional: true
  # source='reimbursement' 時的來源代墊款（核准時由後端寫入 source_ref_id）；一般支出為 nil。
  belongs_to :source_reimbursement, class_name: "Reimbursement", foreign_key: :source_ref_id, optional: true
  # 固定支出範本產生時指回；範本永久刪除後為 nil，recurring_period 保留。
  belongs_to :recurring_template, optional: true
  # 手續費支出指回產生它的移轉；手續費改為 0 後仍保留。
  belongs_to :transfer, optional: true
  # 這筆是移轉目前對應的手續費時才有值。只取判斷要用的欄位，避免載入憑證。
  has_one :current_fee_transfer, -> { select(:id, :fee_expense_id) }, class_name: "Transfer",
          foreign_key: :fee_expense_id, inverse_of: false
  # 圖檔（docs/資料模型.md §2.4）。永久刪除時拿掉，沒有其他紀錄使用的實體檔案才刪。
  has_many_attached :attachments

  validates :source,        inclusion: { in: SOURCES }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validates :tax_rate,      inclusion: { in: TAX_RATES }
  validates :payout_status, inclusion: { in: PAYOUT_STATUSES }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :date,   presence: true
  validates :planned_payout_date, presence: true
  validates :invoice_date, presence: { message: "發票須填發票日期" }, if: -> { document_type == "invoice" }

  # 日期規則（PRD 第 23 條）：收據沒有發票日期；應付日期沒有值時用預設值。沒手動改過、
  # 且自動值為 null（建立當下公司關閉付款日）時，應付日期就是發生日期，改發生日期會跟著改。
  before_validation :clear_invoice_date_for_receipt
  before_validation :follow_default_planned_payout_date

  validate :category_belongs_to_same_company
  validate :tax_id_required_for_invoice
  validate :tax_id_format

  scope :general,            -> { where(source: "general") }
  scope :from_reimbursement, -> { where(source: "reimbursement") }
  scope :pending,            -> { where(payout_status: "pending") }
  scope :paid,               -> { where(payout_status: "paid") }
  scope :settled,            -> { paid }
  # 固定紀錄的 source 仍是 general，一律以 recurring_period 判斷。
  scope :recurring,          -> { where.not(recurring_period: nil) }
  scope :non_recurring,      -> { where(recurring_period: nil) }
  # 使用者自己登錄的紀錄，不含系統產生的固定紀錄與手續費。
  scope :user_entered,       -> { non_recurring.where.not(source: "transfer_fee") }
  scope :missing_invoice_no, -> { where(document_type: "invoice", invoice_no: [ nil, "" ]) }

  # 軟刪除：kept 為一般列表、discarded 為垃圾桶。預設不加 default_scope，
  # 由 controller 明確選擇，以免 Reimbursement/Budget 等 cross-model query 誤漏資料。
  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  def self.cash_date = :paid_at

  # 應付日期的預設值：登錄或核准當下依付款日算出的日期；沒有時為發生日期。
  def default_planned_payout_date
    auto_planned_payout_date || date
  end

  # 登錄或核准當下設定自動值（之後不再變動）。recorded_on 為登錄日或核准日。
  def snapshot_planned_payout!(recorded_on)
    self.auto_planned_payout_date = PayoutSchedule.snapshot(recorded_on, company.payout_day)
    self.planned_payout_manual    = false
  end

  # 使用者送出的應付日期：和預設值不同才算手動修改；nil 表示改回自動排程。
  # 須在發生日期設定之後呼叫。
  def assign_planned_payout_date(value)
    if value.nil?
      self.planned_payout_date   = default_planned_payout_date
      self.planned_payout_manual = false
    else
      self.planned_payout_date   = value
      self.planned_payout_manual = value != default_planned_payout_date
    end
  end

  def transfer_fee?
    source == "transfer_fee"
  end

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

  # create / purge 寫入 AuditLog 的核心快照（business-level 欄位，不含內部 id 格式）。
  # 一般新增、代墊款核准、Excel 匯入共用。
  def audit_snapshot
    snapshot = {
      source:        source,
      source_ref_id: source_ref_id&.to_s,
      vendor:        vendor,
      amount:        amount&.to_f,
      date:          date&.iso8601,
      invoice_date:  invoice_date&.iso8601,
      planned_payout_date: planned_payout_date&.iso8601,
      category_id:   category_id&.to_s,
      category_name: category&.name,
      account_id:    account_id&.to_s,
      account_name:  account&.name,
      note:          note,
      payout_status: payout_status,
      paid_at:       paid_at&.iso8601
    }
    files = AttachmentFiles.audit_details(self)
    snapshot[:attachments] = files if files
    transfer_fee? ? snapshot.merge(via: TransferFeeExpense::VIA) : snapshot
  end

  private

  def clear_invoice_date_for_receipt
    self.invoice_date = nil unless document_type == "invoice"
  end

  def follow_default_planned_payout_date
    following = !planned_payout_manual && auto_planned_payout_date.nil? && date_changed?
    self.planned_payout_date = default_planned_payout_date if planned_payout_date.nil? || following
  end

  # 跨公司引用是多租戶隔離漏洞——守門（比照 Budget#category_belongs_to_same_company）。
  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
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
