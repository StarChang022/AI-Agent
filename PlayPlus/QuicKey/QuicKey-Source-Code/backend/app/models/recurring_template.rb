class RecurringTemplate < ApplicationRecord
  # 固定收支範本（docs/資料模型.md §2.8、PRD 第 17 條）。依週期產生待收款、待付款紀錄，
  # 產生的紀錄就是一般 Expense、Income，由 RecurringGenerator 建立。
  # 沒有下一期可產生時視為到期，移至「歷史」；是否到期即時計算，不存檔。
  # 驗證錯誤的 type 就是 API 的錯誤代碼（docs/dev/recurring-api.md）。

  DIRECTIONS  = %w[income expense].freeze
  FREQUENCIES = %w[monthly yearly].freeze
  STATUSES    = %w[active history trash].freeze
  NAME_MAX         = 50
  COUNTERPARTY_MAX = 100
  MAX_AMOUNT       = BigDecimal("9999999999.99")
  MIN_MONTH        = "2000-01".freeze
  MONTH_FORMAT     = /\A\d{4}-(0[1-9]|1[0-2])\z/
  NO_PERIODS_MESSAGE = "開始到結束月份之間沒有任何一期，請調整週期或月份".freeze
  CATEGORY_BLOCK_MESSAGES = {
    "CATEGORY_IN_TRASH" => "範本使用的類別在垃圾桶，請先還原類別",
    "CATEGORY_ARCHIVED" => "範本使用的類別已停用，請先重新啟用類別"
  }.freeze

  belongs_to :company
  belongs_to :created_by, class_name: "User"
  # 必填與公司隔離由 category_usable、account_usable 檢查，錯誤代碼才一致。
  belongs_to :category, optional: true
  belongs_to :account, optional: true
  # 永久刪除範本時清空 recurring_template_id；recurring_period 保留，「固定」標示還在。
  has_many :expenses, dependent: :nullify
  has_many :incomes,  dependent: :nullify

  before_validation :normalize

  validate :direction_valid, :name_valid
  validate :category_usable, if: -> { new_record? || category_id_changed? }
  validate :account_usable,  if: -> { new_record? || account_id_changed? }
  validate :document_valid, :counterparty_valid, :amount_valid
  validate :schedule_valid, :months_valid, :has_periods
  validate :start_month_unlocked, on: :update, if: :start_month_changed?

  scope :kept,      -> { where(deleted_at: nil) }
  scope :discarded, -> { where.not(deleted_at: nil) }

  # 這次編輯儲存後要不要當場產生，由 apply_edit 算出。
  attr_reader :generate_on_save

  def discarded?
    deleted_at.present?
  end

  def discard!
    return self if discarded?
    update!(deleted_at: Time.current)
  end

  # 不補垃圾桶期間的期數，從今天所在的月份開始。
  def restore_from_trash!(today:)
    return self unless discarded?
    update!(deleted_at: nil, resume_period: month_of(today))
  end

  def yearly?
    frequency == "yearly"
  end

  # 已產生過紀錄就不可改開始月份，紀錄後來被刪掉也一樣。
  def start_month_locked?
    last_generated_period.present?
  end

  # 週期日：月份沒有這一天時落在當月最後一天。
  def due_date(period)
    year, month = split_period(period)
    Date.new(year, month, [ day_of_month, Time.days_in_month(month, year) ].min)
  end

  # 「從當期開始產生」的起點。每年週期只有今天所在的月份是週期月份才算當期，
  # 其他月份從這裡往後找，就是下一個週期月份。
  def month_of(today)
    format_period(today.year, today.month)
  end

  # 下一個要產生的期數；沒有時為 nil，範本視為到期。
  def next_period
    floor  = [ start_month, resume_period, after_last_generated ].compact.max
    period = first_period_from(floor)
    period unless past_end?(period)
  end

  def expired?
    next_period.nil?
  end

  def status
    return "trash" if discarded?
    expired? ? "history" : "active"
  end

  # 週期日已到、還沒產生的期數。
  def due_periods(today)
    periods = []
    period  = next_period
    while period && !past_end?(period) && due_date(period) <= today
      periods << period
      period = following(period)
    end
    periods
  end

  # 開始到結束月份之間是否至少有一期，不看已產生到哪裡。
  # 已產生過紀錄時不檢查：結束月份可以早於已產生的期數。
  def periods_in_range?
    start_month_locked? || !past_end?(first_period_from(start_month))
  end

  # 編輯：套用表單的值，算好儲存時的起點與要不要當場產生。PATCH 與 preview 共用，
  # 預覽的筆數才會和實際一致。回傳 false 時不可儲存，原因在 errors。
  def apply_edit(attrs, today:, preview: false)
    was_history = expired?
    assign_attributes(attrs)
    return false unless preview ? preview_valid? : valid?

    reviving = was_history && !expired?
    return false if (reviving || end_month_extended?) && category_blocked?

    self.resume_period = month_of(today) if reviving
    self.resume_period = resume_after_schedule_change(today) if schedule_changed?
    @generate_on_save = (reviving && !expired?) || start_month_changed? || cycle_changed? || day_of_month_changed?
    true
  end

  # 結束月份往後延（含改成持續產生）。
  def end_month_extended?
    return false if !end_month_changed? || end_month_was.nil?
    end_month.nil? || end_month > end_month_was
  end

  # 回到進行中前檢查類別，擋下時原因寫進 errors。
  # 鎖住類別列到交易結束，和 CategoriesController 的 lock! 互斥。
  def category_blocked?
    deleted_at, archived = Category.where(id: category_id).lock("FOR SHARE").pick(:deleted_at, :is_archived)
    code = "CATEGORY_IN_TRASH" if deleted_at
    code ||= "CATEGORY_ARCHIVED" if archived
    errors.add(:category_id, code.to_sym, message: CATEGORY_BLOCK_MESSAGES.fetch(code)) if code
    code.present?
  end

  # preview 用：只檢查和產生期數有關的欄位。
  def preview_valid?
    normalize
    errors.clear
    schedule_valid
    months_valid
    start_month_unlocked if start_month_changed?
    category_usable if persisted? && category_id_changed?
    errors.empty?
  end

  def audit_snapshot
    {
      direction:      direction,
      name:           name,
      category_id:    category_id&.to_s,
      category_name:  category&.name,
      account_id:     account_id&.to_s,
      account_name:   account&.name,
      document_type:  document_type,
      tax_rate:       tax_rate,
      counterparty:   counterparty,
      tax_id:         tax_id,
      amount:         amount&.to_f,
      frequency:      frequency,
      day_of_month:   day_of_month,
      month_of_year:  month_of_year,
      start_month:    start_month,
      end_month:      end_month,
      last_generated_period: last_generated_period
    }
  end

  private

  def cycle_changed?
    frequency_changed? || month_of_year_changed?
  end

  # 週期有變且已產生過紀錄時，已過的期數不補。只改週期日不算：不補也不跳過。
  def schedule_changed?
    start_month_locked? && cycle_changed?
  end

  # 修改週期後的起點：從今天所在的月份依新週期產生。每年週期改月份時同一年只一筆，
  # 那一年已產生過就從隔年開始。
  def resume_after_schedule_change(today)
    return month_of(today) unless yearly? && frequency_was == "yearly"
    [ month_of(today), format_period(split_period(last_generated_period).first + 1, 1) ].max
  end

  def split_period(period)
    period.split("-").map(&:to_i)
  end

  def format_period(year, month)
    format("%04d-%02d", year, month)
  end

  def past_end?(period)
    end_month.present? && period > end_month
  end

  # floor 當月或之後的第一期。
  def first_period_from(floor)
    return floor unless yearly?
    year, month = split_period(floor)
    format_period(month <= month_of_year ? year : year + 1, month_of_year)
  end

  def following(period)
    first_period_from(month_after(period))
  end

  def month_after(period)
    year, month = split_period(period)
    month == 12 ? format_period(year + 1, 1) : format_period(year, month + 1)
  end

  def after_last_generated
    last_generated_period && month_after(last_generated_period)
  end

  def normalize
    self.name          = name.to_s.strip
    self.counterparty  = counterparty.to_s.strip
    self.tax_id        = tax_id.to_s.strip.presence
    self.end_month     = end_month.presence
    self.month_of_year = nil unless yearly?
    # 收據一律免稅，和手動新增、Excel 匯入一致。
    self.tax_rate      = "exempt_0" if document_type == "receipt"
  end

  def direction_valid
    return if DIRECTIONS.include?(direction)
    errors.add(:direction, :INVALID_DIRECTION, message: "請選擇固定收入或固定支出")
  end

  def name_valid
    return if name.present? && name.length <= NAME_MAX
    errors.add(:name, :INVALID_NAME, message: "請填寫名稱，最多 #{NAME_MAX} 字")
  end

  # 鎖住類別列到交易結束，和 CategoriesController 的 lock! 互斥：否則檢查完類別
  # 馬上被停用或刪除，會留下進行中範本使用的停用類別。
  def category_usable
    kind = Category.active.where(id: category_id, company_id: company_id).lock("FOR SHARE").pick(:kind)
    if kind.nil?
      errors.add(:category_id, :CATEGORY_NOT_FOUND, message: "找不到這個類別，請重新選擇")
    elsif kind != direction
      errors.add(:category_id, :CATEGORY_WRONG_KIND, message: "類別的類型和收支方向不同")
    end
  end

  # 鎖住帳戶列到交易結束，和 AccountsController#destroy 的 lock! 互斥。
  def account_usable
    if account_id.blank?
      errors.add(:account_id, :ACCOUNT_REQUIRED, message: "請選擇帳戶")
    elsif !Account.kept.where(id: account_id, company_id: company_id).lock("FOR SHARE").exists?
      errors.add(:account_id, :ACCOUNT_NOT_FOUND, message: "找不到這個帳戶，請重新選擇")
    end
  end

  def document_valid
    unless Expense::DOCUMENT_TYPES.include?(document_type)
      errors.add(:document_type, :INVALID_DOCUMENT_TYPE, message: "請選擇文件類型")
    end
    unless Expense::TAX_RATES.include?(tax_rate)
      errors.add(:tax_rate, :INVALID_TAX_RATE, message: "請選擇稅別")
    end
    if document_type == "invoice" && tax_id.blank?
      errors.add(:tax_id, :TAX_ID_REQUIRED, message: "發票須填統一編號")
    elsif tax_id.present? && !tax_id.match?(/\A\d{8}\z/)
      errors.add(:tax_id, :INVALID_TAX_ID, message: "統一編號應為 8 碼數字")
    end
  end

  def counterparty_valid
    return if counterparty.present? && counterparty.length <= COUNTERPARTY_MAX
    errors.add(:counterparty, :INVALID_COUNTERPARTY, message: "請填寫廠商或客戶，最多 #{COUNTERPARTY_MAX} 字")
  end

  # 看原始值：寫入欄位時已依資料表的小數位數四捨五入，查不出超過兩位小數。
  def amount_valid
    value = BigDecimal(amount_before_type_cast.to_s)
    return if value.positive? && value <= MAX_AMOUNT && value == value.round(2)
    add_invalid_amount
  rescue ArgumentError
    add_invalid_amount
  end

  def add_invalid_amount
    errors.add(:amount, :INVALID_AMOUNT, message: "請填寫金額，需大於 0，最多兩位小數")
  end

  def schedule_valid
    valid = FREQUENCIES.include?(frequency) && day_of_month.to_i.between?(1, 31) &&
            (!yearly? || month_of_year.to_i.between?(1, 12))
    errors.add(:frequency, :INVALID_SCHEDULE, message: "請選擇週期") unless valid
  end

  def months_valid
    message =
      if !month_in_range?(start_month)
        "請選擇開始月份，不可早於 2000 年 1 月"
      elsif end_month.present? && !month_in_range?(end_month)
        "結束月份格式不正確"
      elsif end_month.present? && end_month < start_month
        "結束月份不可早於開始月份"
      end
    errors.add(:start_month, :INVALID_MONTH, message: message) if message
  end

  def month_in_range?(month)
    month.to_s.match?(MONTH_FORMAT) && month >= MIN_MONTH
  end

  def has_periods
    return if errors.any? || periods_in_range?
    errors.add(:base, :NO_PERIODS, message: NO_PERIODS_MESSAGE)
  end

  def start_month_unlocked
    return unless start_month_locked?
    errors.add(:start_month, :START_MONTH_LOCKED, message: "已產生過紀錄，不可修改開始月份")
  end
end
