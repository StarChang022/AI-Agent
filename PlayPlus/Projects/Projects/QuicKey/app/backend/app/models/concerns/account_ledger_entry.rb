# 帶帳戶的收支（Expense、Income）共用：帳戶驗證、計入帳戶現金流的範圍。
# include 的 model 要提供 cash_date（收付款日欄位）與 settled（已收付）scope。
module AccountLedgerEntry
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    validate :account_belongs_to_same_company
    validate :account_not_deleted, if: -> { new_record? || account_id_changed? }
  end

  class_methods do
    # 計入帳戶現金流與餘額的紀錄：已收付、未刪除、收付款日不早於帳戶起始月份。
    def in_ledger
      kept.settled.joins(:account).where("#{table_name}.#{cash_date} >= accounts.opening_month")
    end
  end

  private

  # 跨公司引用是多租戶隔離漏洞——守門。
  def account_belongs_to_same_company
    return if company_id.blank? || account.nil?
    errors.add(:account_id, "belongs to another company") if account.company_id != company_id
  end

  # 鎖住帳戶列到交易結束，和 AccountsController#destroy 的 lock! 互斥：
  # 否則查完帳戶未刪除後，帳戶可能馬上被刪除，留下指向垃圾桶帳戶的紀錄。
  def account_not_deleted
    return if account_id.blank?
    return if Account.kept.where(id: account_id).lock("FOR SHARE").exists?
    errors.add(:account_id, :deleted, message: "帳戶已刪除")
  end
end
