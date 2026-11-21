module DataExports
  # 背景產生結束（完成或失敗）時通知發起人：站內通知＋寄信（docs/通知提醒.md 第 6、7 項）。
  # 兩者各自處理錯誤，一邊失敗不影響另一邊，也不影響匯出結果。
  module Notifier
    module_function

    def call(export)
      ready = export.status == "completed"

      begin
        ready ? Notifications.notify_data_export_ready(export) : Notifications.notify_data_export_failed(export)
      rescue StandardError => e
        Rails.logger.error("[DataExport] #{export.id} notification failed: #{e.class}: #{e.message}")
      end

      begin
        (ready ? DataExportMailer.ready(export) : DataExportMailer.failed(export)).deliver_now
      rescue StandardError => e
        Rails.logger.error("[DataExport] #{export.id} mail failed: #{e.class}: #{e.message}")
      end
    end
  end
end
