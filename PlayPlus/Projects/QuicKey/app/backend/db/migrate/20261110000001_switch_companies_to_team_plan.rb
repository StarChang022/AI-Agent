# 封測期間所有公司都是團隊版（docs/資料模型.md §3.1「方案上限」，2026-11-10）。
#
# 1. plan 預設由 free 改 team，既有公司一律改 team。
# 2. 每月辨識次數預設由 50 改 160；仍是舊預設 50 的公司一併改 160，個別調整過的不動。
#    本月已用次數（ocr_monthly_used）不歸零。
class SwitchCompaniesToTeamPlan < ActiveRecord::Migration[8.1]
  def up
    change_column_default :companies, :plan, from: "free", to: "team"
    change_column_default :companies, :ocr_monthly_quota, from: 50, to: 160

    execute "UPDATE companies SET plan = 'team', updated_at = NOW() WHERE plan <> 'team'"
    execute "UPDATE companies SET ocr_monthly_quota = 160, updated_at = NOW() WHERE ocr_monthly_quota = 50"
  end

  # 只還原預設值；資料無法分辨原本是哪些公司被改過，不回寫。
  def down
    change_column_default :companies, :plan, from: "team", to: "free"
    change_column_default :companies, :ocr_monthly_quota, from: 160, to: 50
  end
end
