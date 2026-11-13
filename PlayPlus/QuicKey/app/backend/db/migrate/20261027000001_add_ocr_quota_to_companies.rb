# OCR 配額（docs/OCR辨識規格.md §5）：每家公司兩池次數。
# - 月費額度：ocr_monthly_quota / ocr_monthly_used，每月 1 日 00:00（台北時間）歸零
# - 加購包：ocr_purchased_remaining，不過期、永久累積
# ocr_quota_reset_at = 下次 monthly_used 歸零的時間；/api/ocr/* 被呼叫時才檢查是否過期（lazy 重置，不開 cron）。
class AddOcrQuotaToCompanies < ActiveRecord::Migration[8.1]
  # 「下個月 1 日 00:00 台北時間」換算成 UTC 存（Rails datetime 欄位以 UTC 存）。
  # 用 DB default，新公司建立時不用在 model 另外補值；既有公司也會一併帶入。
  # 最外層括號必要：PostgreSQL 的 DEFAULT 子句不接受未加括號的 AT TIME ZONE。
  NEXT_MONTH_START_SQL = <<~SQL.squish
    (((date_trunc('month', now() AT TIME ZONE 'Asia/Taipei') + interval '1 month')
      AT TIME ZONE 'Asia/Taipei') AT TIME ZONE 'UTC')
  SQL

  def change
    add_column :companies, :ocr_monthly_quota,       :integer, null: false, default: 20
    add_column :companies, :ocr_monthly_used,        :integer, null: false, default: 0
    add_column :companies, :ocr_purchased_remaining, :integer, null: false, default: 0
    add_column :companies, :ocr_quota_reset_at,      :datetime, null: false, default: -> { NEXT_MONTH_START_SQL }
  end
end
