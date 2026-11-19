class PurgeStaleUploadsJob < ApplicationJob
  # 每日排程（config/recurring.yml）：刪除建立超過 24 小時仍未掛上紀錄的暫存圖檔
  # （關閉頁面等沒能即時刪除的；docs/資料模型.md §2.4）。
  queue_as :default

  def perform
    AttachmentFiles.purge_stale!
  end
end
