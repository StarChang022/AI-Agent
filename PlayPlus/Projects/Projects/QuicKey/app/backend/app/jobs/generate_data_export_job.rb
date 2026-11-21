class GenerateDataExportJob < ApplicationJob
  # 資料匯出的背景產生（PRD 第 24 條）：產生檔案後寄完成信、寫站內通知；失敗時記下原因
  # （不給使用者看），寄失敗信請對方重新匯出。不自動重試，避免重複寄信。
  # 卡住沒跑完的由 CleanUpDataExportsJob 逾時回收。
  queue_as :default

  def perform(data_export_id)
    export = DataExport.find_by(id: data_export_id)
    # 只處理還在排隊的：重複執行、已被逾時回收的都略過
    return unless export&.transition!(from: "queued", to: "processing")

    begin
      count = DataExports::Generator.new(export).call
    rescue StandardError => e
      Rails.logger.error("[DataExport] #{export.id} failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
      export.files.purge
      DataExports::Notifier.call(export) if export.transition!(from: "processing", to: "failed", error: "#{e.class}: #{e.message}")
      return
    end

    now = Time.current
    if export.transition!(from: "processing", to: "completed", record_count: count, completed_at: now, expires_at: now + DataExport::TTL)
      DataExports::Notifier.call(export)
    else
      # 產生途中已被逾時回收標成失敗（也已通知），這次的檔案不留
      export.files.purge
    end
  end
end
