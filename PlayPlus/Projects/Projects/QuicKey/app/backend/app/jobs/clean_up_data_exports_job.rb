class CleanUpDataExportsJob < ApplicationJob
  # 每小時排程（config/recurring.yml），資料匯出的兩件善後（docs/資料模型.md §3.7、
  # docs/dev/data-export-api.md 第 8 節）：
  # 1. 刪除已失效的匯出檔，DataExport 本身保留，稽核日誌才對得到。
  # 2. 發起超過 DataExport::STUCK_AFTER 仍未完成的（背景工作卡住），標成失敗並照失敗流程
  #    寄信、寫站內通知；產生到一半的檔案一併刪除。
  queue_as :default

  def perform
    DataExport.expired.where.associated(:files_attachments).distinct.find_each do |export|
      export.files.purge
    end

    DataExport.stuck.find_each do |export|
      next unless export.transition!(from: export.status, to: "failed", error: "逾時未完成（發起後超過 #{DataExport::STUCK_AFTER.in_hours.to_i} 小時）")

      export.files.purge
      DataExports::Notifier.call(export)
    end
  end
end
