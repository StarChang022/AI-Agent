class BudgetTemplate < ApplicationRecord
  # 基本預算範本——每公司每類別每 cycle 一筆，作為使用者「套用到某期間」的來源。
  # 編輯 template 不會影響任何 Budget 記錄；套用（apply）才把 template 值鏡射到指定期間。
  # amount = 0 或缺 template 於套用時視為「取消該期間預算」（見 BudgetTemplatesController#apply）。

  CYCLES = %w[month year].freeze

  belongs_to :company
  belongs_to :category

  validates :cycle,  inclusion: { in: CYCLES }
  validates :amount, presence: true, numericality: { greater_than: 0 }

  validates :category_id,
    uniqueness: { scope: %i[company_id cycle] }

  validate :category_belongs_to_same_company

  private

  def category_belongs_to_same_company
    return if company_id.blank? || category.nil?
    errors.add(:category_id, "belongs to another company") if category.company_id != company_id
  end
end
