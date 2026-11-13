class DataExport < ApplicationRecord
  # 資料匯出（docs/資料模型.md §3.7、PRD 第 24 條、docs/dev/data-export-api.md）。
  # 每次發起匯出建一筆，一次只匯出一個列表（支出／收入／代墊款）。沒有圖檔的當下下載，
  # 建立即 completed、不存檔；有圖檔的排背景產生，檔案掛在 files，完成後 7 天失效，排程刪檔、這筆保留。

  # single：明細單筆；selected：勾選；filtered：列表目前的分頁標籤與篩選。
  SCOPES   = %w[single selected filtered].freeze
  KINDS    = %w[expense income reimbursement].freeze
  STATUSES = %w[queued processing completed failed].freeze
  TTL      = 7.days
  # 發起後超過這個時間仍在 queued／processing，視為背景工作卡住（worker 被停掉、機器重啟），
  # 每小時檢查時標成失敗並通知（docs/dev/data-export-api.md 第 8 節）。
  STUCK_AFTER = 3.hours

  # files 每個檔案的 metadata["key"]：expense_csv / income_csv / reimbursement_csv / attachments_zip。
  FILE_KEYS = %w[expense_csv income_csv reimbursement_csv attachments_zip].freeze

  KIND_LABELS = { "expense" => "支出", "income" => "收入", "reimbursement" => "代墊款" }.freeze

  belongs_to :company
  belongs_to :requested_by, class_name: "User"

  has_many_attached :files

  validates :scope,  inclusion: { in: SCOPES }
  validates :kind,   inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :expired, -> { where(expires_at: ...Time.current) }
  scope :stuck,   -> { where(status: %w[queued processing], created_at: ...STUCK_AFTER.ago) }

  # 狀態從 from 改成 to，回是否改成功。用條件更新，背景工作與逾時回收同時處理同一筆時
  # 只有一方會成功，不會重複寄信，也不會把已標失敗的改回完成。
  def transition!(from:, to:, **attrs)
    changed = self.class.where(id: id, status: from).update_all(status: to, updated_at: Time.current, **attrs) == 1
    reload if changed
    changed
  end

  # 有圖檔才在背景產生（存檔、寄信）。
  def background?
    with_attachments
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def downloadable?
    status == "completed" && !expired?
  end

  def file_for(key)
    files_attachments.includes(:blob).find { |a| a.blob.metadata["key"] == key }&.blob
  end

  # 下載頁、稽核日誌、通知共用的範圍文字。
  # 例：「支出 單筆」「代墊款 勾選 5 筆」「支出 2026/11/01–2026/11/30」「收入 全部」。
  def scope_label
    "#{KIND_LABELS[kind]} #{scope_detail}"
  end

  # 稽核日誌 after。recordCount 為發起當下的筆數。
  def audit_snapshot
    {
      scope:            scope,
      kind:             kind,
      criteria:         criteria,
      record_count:     record_count,
      with_attachments: with_attachments
    }
  end

  private

  # filtered 只看發生日期區間，其他篩選不寫進文字；只選一端時寫「起」「至」。
  def scope_detail
    case scope
    when "single"   then "單筆"
    when "selected" then "勾選 #{Array(criteria["ids"]).size} 筆"
    else
      from, to = criteria.values_at("date_from", "date_to").map { |d| d.presence&.tr("-", "/") }
      if from && to then "#{from}–#{to}"
      elsif from    then "#{from} 起"
      elsif to      then "至 #{to}"
      else "全部"
      end
    end
  end
end
