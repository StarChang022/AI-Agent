class DataExportMailer < ApplicationMailer
  # 資料匯出完成／失敗通知（PRD 第 24 條、docs/通知提醒.md 第 6、7 項），寄給發起的管理員。
  # 連結指向前端下載頁；未登入時前端先導向登入，登入後回到下載頁。
  def ready(data_export)
    setup(data_export)
    @expires_at = data_export.expires_at.in_time_zone.strftime("%Y/%m/%d %H:%M")
    mail(to: @user.email, subject: "【Quickey】資料匯出已完成")
  end

  def failed(data_export)
    setup(data_export)
    mail(to: @user.email, subject: "【Quickey】資料匯出失敗")
  end

  private

  def setup(data_export)
    @export = data_export
    @user   = data_export.requested_by
    @url    = "#{Rails.configuration.frontend_base_url}/admin/exports/#{data_export.id}"
  end
end
