class Transfer < ApplicationRecord
  # 資金移轉（docs/資料模型.md §2.10、PRD 第 19 條）。不屬於收入或支出，只影響兩個帳戶的餘額。
  # 手續費大於 0 時由 TransferFeeExpense 產生一筆支出。
  # 驗證錯誤的 type 就是 API 的錯誤代碼（docs/dev/transfers-api.md）。

  MAX_AMOUNT  = Account::MAX_AMOUNT
  SIDE_LABELS = { from: "轉出", to: "轉入" }.freeze

  belongs_to :company
  belongs_to :created_by, class_name: "User"
  # 必填與公司隔離由 accounts_usable 檢查，錯誤代碼才一致。
  belongs_to :from_account, class_name: "Account", optional: true
  belongs_to :to_account,   class_name: "Account", optional: true
  # 手續費目前對應的支出；手續費為 0 時為空。
  belongs_to :fee_expense, class_name: "Expense", optional: true
  # 所有指向這筆移轉的支出，包含手續費改為 0 留在垃圾桶的。
  has_many :expenses

  before_validation :normalize

  validate :accounts_usable, unless: :discarded?
  validate :transfer_date_present, :amount_valid, :fee_valid, :attachments_within_limits

  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }
  scope :involving, ->(account_id) { where(from_account_id: account_id).or(where(to_account_id: account_id)) }

  def discarded?
    deleted_at.present?
  end

  def discard!
    return self if discarded?
    update!(deleted_at: Time.current)
  end

  # 還原也要過驗證：垃圾桶內的移轉不擋帳戶調整起始月份，日期可能已早於起始月份。
  def restore_from_trash
    self.deleted_at = nil
    save
  end

  # create / purge 寫入 AuditLog 的核心快照。
  def audit_snapshot
    {
      from_account_id:   from_account_id&.to_s,
      from_account_name: from_account&.name,
      to_account_id:     to_account_id&.to_s,
      to_account_name:   to_account&.name,
      amount:            amount&.to_f,
      fee:               fee&.to_f,
      transfer_date:     transfer_date&.iso8601,
      note:              note
    }
  end

  private

  def normalize
    self.note = note.presence
    self.fee  = 0 if fee_before_type_cast.blank?
  end

  # 依 id 順序鎖住兩個帳戶到交易結束，和 AccountsController 的 lock! 互斥：否則檢查完帳戶
  # 可能馬上被刪除，或起始月份被調到移轉之後。固定順序才不會和反方向的移轉互等。
  def accounts_usable
    sides = { from: from_account_id, to: to_account_id }

    blank = sides.select { |_, id| id.blank? }.keys
    return add_account_error(:ACCOUNT_REQUIRED, "請選擇#{blank.map { |s| SIDE_LABELS[s] }.join("與")}帳戶", blank) if blank.any?
    return add_account_error(:SAME_ACCOUNT, "轉出與轉入帳戶不能相同", sides.keys) if from_account_id == to_account_id

    accounts = Account.kept.where(id: sides.values, company_id: company_id).order(:id).lock("FOR SHARE").index_by(&:id)
    missing  = sides.keys.reject { |side| accounts.key?(sides[side]) }
    return add_account_error(:ACCOUNT_NOT_FOUND, "找不到這個帳戶，請重新選擇", missing) if missing.any?
    return if transfer_date.nil?

    late = sides.select { |_, id| transfer_date < accounts[id].opening_month }
    return if late.empty?

    names = late.values.map { |id| "「#{accounts[id].name}」（#{accounts[id].opening_month.strftime("%Y-%m")}）" }.join("、")
    # 帳戶名稱走插值參數：寫死在 message 裡，名稱含 %{ 時 I18n 會出錯。
    add_account_error(:TRANSFER_DATE_BEFORE_OPENING, "移轉日期早於%{names}的起始月份，請先把帳戶的起始月份和起始金額往前調",
                      late.keys, names: names)
  end

  def add_account_error(code, message, sides, **options)
    errors.add(:base, code, message: message, sides: sides, **options)
  end

  def transfer_date_present
    errors.add(:transfer_date, :INVALID_TRANSFER_DATE, message: "請選擇移轉日期") if transfer_date.nil?
  end

  def amount_valid
    return if money_valid?(amount_before_type_cast) { |value| value.positive? }
    errors.add(:amount, :INVALID_AMOUNT, message: "請填寫金額，需大於 0，最多兩位小數")
  end

  def fee_valid
    return if money_valid?(fee_before_type_cast) { |value| !value.negative? }
    errors.add(:fee, :INVALID_FEE, message: "手續費不可為負，最多兩位小數")
  end

  # 看原始值：寫入欄位時已依資料表的小數位數四捨五入，查不出超過兩位小數。
  def money_valid?(raw)
    value = BigDecimal(raw.to_s)
    !value.nan? && yield(value) && value <= MAX_AMOUNT && value == value.round(2)
  rescue ArgumentError
    false
  end

  # attachments 是 jsonb 陣列 [{data_url, filename, mime_type}, ...]；只驗 data_url。
  def attachments_within_limits
    data_urls = Array(attachments).map do |a|
      a.is_a?(Hash) ? (a["data_url"] || a[:data_url]) : nil
    end.compact
    ReceiptAttachmentValidation.apply(self, :attachments, data_urls)
  end
end
