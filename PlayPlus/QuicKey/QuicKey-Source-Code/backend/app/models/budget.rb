class Budget < ApplicationRecord
  # 類別預算——一筆對應某公司某類別於某 (cycle, periodStart) 的預算金額。
  # 唯一鍵 (company_id, category_id, cycle, period_start)；amount 必 > 0，
  # 金額歸零由 controller 轉為 DELETE（見 CreateBudgetRequest JSDoc）。

  CYCLES = %w[month year].freeze

  belongs_to :company
  belongs_to :category

  validates :cycle,        inclusion: { in: CYCLES }
  validates :amount,       presence: true, numericality: { greater_than: 0 }
  validates :period_start, presence: true
  validates :period_end,   presence: true

  validates :category_id,
    uniqueness: { scope: %i[company_id cycle period_start] }

  validate  :period_matches_cycle
  validate  :category_belongs_to_same_company

  private

  # month cycle → periodStart 必為該月 1 號、periodEnd 為該月最後一天
  # year cycle  → periodStart 必為 YYYY-01-01、periodEnd 為 YYYY-12-31
  def period_matches_cycle
    return if period_start.blank? || period_end.blank? || cycle.blank?

    case cycle
    when "month"
      valid = period_start.day == 1 && period_end == period_start.end_of_month
      errors.add(:period_start, "does not align with month cycle") unless valid
    when "year"
      valid = period_start.month == 1 && period_start.day == 1 && period_end == period_start.end_of_year
      errors.add(:period_start, "does not align with year cycle") unless valid
    end
  end

  # 跨公司引用是資料一致性漏洞——多租戶隔離守門。
  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
  end
end
