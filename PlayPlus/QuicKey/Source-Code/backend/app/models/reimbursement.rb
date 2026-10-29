class Reimbursement < ApplicationRecord
  # 代墊款請款（docs/資料模型.md §2.1、§4.1）。員工提交、走 6 狀態機、需一層 admin 審核。
  # 已實作：CRUD（建立 / 查詢 / 編輯 / 刪除）、核准（approve → 自動建支出並連動）。
  # 核准後撥款以「支出付款」帶動（Expense#pay 連帶把本筆設為 paid）。
  # 駁回 / 作廢 / 撤回等其餘狀態轉移留待後續模組。可編輯 / 刪除僅限 draft、rejected（§F）。

  STATUSES        = %w[draft in_review rejected approved paid voided].freeze
  DOCUMENT_TYPES  = %w[invoice receipt].freeze
  TAX_RATES       = %w[business_5 exempt_0].freeze
  PAYMENT_METHODS = %w[bank_transfer cash].freeze
  # 申請人可自行編輯 / 刪除的狀態：草稿、被駁回。其餘狀態一律鎖定。
  EDITABLE_STATUSES = %w[draft rejected].freeze
  # 管理員可作廢的狀態（§Delta F）。paid 已實際撥款，需先 revert_pay 才能作廢。
  VOIDABLE_STATUSES = %w[in_review rejected approved].freeze

  belongs_to :company
  belongs_to :employee, class_name: "User"
  # draft 允許 null 以支援「存了一半的草稿」；draft 以外的 status 由下方
  # category_id presence 驗證把關。
  belongs_to :category, optional: true
  belongs_to :expense, optional: true # 核准時自動建立並回填（雙向 FK 另一側）
  belongs_to :paid_by, class_name: "User", optional: true

  EVENT_TYPES = %w[submit resubmit withdraw approve reject pay void revert_void].freeze

  # 處理歷程 push：寫入 history jsonb 陣列。
  # type 必為 EVENT_TYPES 之一；at 預設當下；by 傳 user id（string）；stage/comment 選填。
  # 僅變更記憶體狀態，不自動 save，呼叫端決定何時持久化（通常與其他欄位一併 update!）。
  def push_event!(type:, by:, at: Time.current, stage: nil, comment: nil)
    raise ArgumentError, "invalid event type: #{type}" unless EVENT_TYPES.include?(type.to_s)
    self.history ||= []
    self.history = history + [ {
      "type"    => type.to_s,
      "at"      => at.is_a?(String) ? at : at.iso8601,
      "by"      => by&.to_s,
      "stage"   => stage,
      "comment" => comment
    }.compact ]
  end

  validates :status,         inclusion: { in: STATUSES }
  validates :document_type,  inclusion: { in: DOCUMENT_TYPES }
  validates :tax_rate,       inclusion: { in: TAX_RATES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true
  # draft 容許存一半（amount / incurred_at / category_id / 統編可空）；
  # 送審 (in_review) 以後必填，由下列 unless :draft? 把關。
  validates :amount, presence: true, numericality: { greater_than: 0 }, unless: :draft?
  validates :incurred_at, presence: true, unless: :draft?
  validates :category_id, presence: true, unless: :draft?

  validate :category_belongs_to_same_company
  validate :receipt_attachments_within_limits
  validate :tax_id_required_for_invoice, unless: :draft?
  validate :tax_id_format

  def draft?
    status == "draft"
  end

  # draft 只有申請人自己看得到；後台列表 / 統計一律排除（§4.1 約束，後台模組會用到）。
  scope :visible, -> { where.not(status: "draft") }

  # 「當前 step 的候選人裡包含某 user」= 這個 user 現在該簽的 pending 項目。
  # 單層簽核：approval_progress.steps[0].candidates 的 string array 內含 user_id。
  scope :pending_for, ->(user_id) {
    where(status: "in_review")
      .where("approval_progress -> 'steps' -> 0 -> 'candidates' @> ?::jsonb", [ user_id.to_s ].to_json)
  }

  # 「我處理過（已簽過的 step 的 reviewed_by）」= 排除 draft / in_review 後，看
  # steps[0].reviewed_by 是否為該 user。單層簽核限定於第一個 step。
  scope :reviewed_by_user, ->(user_id) {
    where.not(status: %w[draft in_review])
      .where("approval_progress -> 'steps' -> 0 ->> 'reviewed_by' = ?", user_id.to_s)
  }

  # 申請人能否編輯 / 刪除（限 draft、rejected）。
  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  private

  # 跨公司引用是多租戶隔離漏洞——守門（比照 Budget#category_belongs_to_same_company）。
  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
  end

  # 憑證張數 / MIME / 單檔大小守門（前端已擋，後端補一層避免繞過 API 直接送）。
  def receipt_attachments_within_limits
    ReceiptAttachmentValidation.apply(self, :receipt_urls, receipt_urls)
  end

  # 發票須有賣方統編；收據選填（小攤販無統編）。對齊前端 validateForSubmit。
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
