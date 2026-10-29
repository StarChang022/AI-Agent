# 基本方案每月 OCR 次數由 20 次調為 50 次（docs/OCR辨識規格.md §5）。
# 新公司靠 default 拿到 50；既有公司只更新仍是舊基本值 20 的，已個別調整過次數的公司不動。
# down 反過來：default 改回 20，仍是 50 的公司改回 20。
class RaiseDefaultOcrMonthlyQuota < ActiveRecord::Migration[8.1]
  OLD_QUOTA = 20
  NEW_QUOTA = 50

  def up
    change_column_default :companies, :ocr_monthly_quota, from: OLD_QUOTA, to: NEW_QUOTA
    execute "UPDATE companies SET ocr_monthly_quota = #{NEW_QUOTA} WHERE ocr_monthly_quota = #{OLD_QUOTA}"
  end

  def down
    change_column_default :companies, :ocr_monthly_quota, from: NEW_QUOTA, to: OLD_QUOTA
    execute "UPDATE companies SET ocr_monthly_quota = #{OLD_QUOTA} WHERE ocr_monthly_quota = #{NEW_QUOTA}"
  end
end
