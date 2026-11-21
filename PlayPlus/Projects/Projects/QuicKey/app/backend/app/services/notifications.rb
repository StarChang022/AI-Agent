module Notifications
  # 代墊款、資料匯出等事件觸發站內通知的統一入口（docs/通知提醒.md）。
  # 各業務 controller 於狀態轉移成功後呼叫對應方法，payload 以 snake_case 儲存，
  # 前端 api/service.ts 會自動轉為 camelCase。寫入失敗不中斷主流程（通知屬非關鍵旁路，見 write）。
  # 第 1～5 項同時寄 Email（NotificationMailer），收件人與站內通知相同、但不寄給停用的人（見 send_mail）。

  # 1. 新待簽核：員工送出 → 通知公司所有 admin。
  # admin 自提時排除自己；若公司只有一名 admin 自提則不通知任何人（避免自己通知自己）。
  def self.notify_submitted(reimbursement)
    actor  = reimbursement.employee
    admins = reimbursement.company.users.where(role: "admin").where.not(id: actor.id).to_a
    return if admins.empty?

    payload = {
      "reimbursement_id" => reimbursement.id.to_s,
      "actor_name"       => actor.name,
      "description"      => reimbursement.description,
      "amount"           => reimbursement.amount.to_f,
      "category_name"    => reimbursement.category&.name
    }

    create_many(reimbursement.company_id, admins.map(&:id), "reimbursement_submitted", payload)
    admins.each { |admin| send_mail(admin) { NotificationMailer.submitted(reimbursement, admin) } }
  end

  # 2. 簽核通過：admin 核准 → 通知員工本人。
  # 預計發放日取自 approve 當下自動建立的連動支出；admin 尚未設定時為 nil。
  def self.notify_approved(reimbursement)
    planned_payout_date = reimbursement.expense&.planned_payout_date
    create_one(
      reimbursement.company_id,
      reimbursement.employee_id,
      "reimbursement_approved",
      base_payload(reimbursement).merge("planned_payout_date" => planned_payout_date&.iso8601)
    )
    send_mail(reimbursement.employee) { NotificationMailer.approved(reimbursement) }
  end

  # 3. 簽核駁回：admin 駁回 → 通知員工本人（含駁回原因，可空）。
  def self.notify_rejected(reimbursement, comment:)
    create_one(
      reimbursement.company_id,
      reimbursement.employee_id,
      "reimbursement_rejected",
      base_payload(reimbursement).merge("comment" => comment.to_s)
    )
    send_mail(reimbursement.employee) { NotificationMailer.rejected(reimbursement, comment.to_s) }
  end

  # 4. 逾期未付：排程器每天掃一次，將當前仍 pending 且 planned_payout_date 已過期的
  # 支出聚合通知該公司全部 admin。payload：
  #   overdue_count 筆數 / max_days 最大逾期天數 / expense_ids 便於前端 deeplink。
  # expenses 空則不發；呼叫端（Job）應預先過濾好當前 company 範圍。
  def self.notify_overdue_payouts(company, expenses, today: Time.zone.today)
    return if expenses.empty?

    admins = company.users.where(role: "admin").to_a
    return if admins.empty?

    max_days = expenses.map { |e| (today - e.planned_payout_date).to_i }.max
    payload = {
      "overdue_count" => expenses.size,
      "max_days"      => max_days,
      "expense_ids"   => expenses.map { |e| e.id.to_s }
    }

    create_many(company.id, admins.map(&:id), "payout_overdue", payload)
    admins.each { |admin| send_mail(admin) { NotificationMailer.overdue_payouts(admin, expenses, today) } }
  end

  # 5. 發放完成：admin 將連動支出標為已付款 → 通知員工本人。
  # payment_method 由上游 sync_linked_reimbursement 寫入後讀取（bank_transfer | cash）。
  def self.notify_paid(reimbursement, paid_at: Time.current)
    create_one(
      reimbursement.company_id,
      reimbursement.employee_id,
      "reimbursement_paid",
      base_payload(reimbursement).merge(
        "paid_at"        => paid_at.iso8601,
        "payment_method" => reimbursement.payment_method
      )
    )
    send_mail(reimbursement.employee) { NotificationMailer.paid(reimbursement, paid_at) }
  end

  # 6. 資料匯出完成：背景產生完成 → 通知發起的管理員，點擊前往下載頁。
  def self.notify_data_export_ready(data_export)
    create_one(
      data_export.company_id,
      data_export.requested_by_id,
      "data_export_ready",
      data_export_payload(data_export).merge(
        "record_count" => data_export.record_count,
        "expires_at"   => data_export.expires_at&.iso8601
      )
    )
  end

  # 7. 資料匯出失敗：背景產生失敗 → 通知發起的管理員重新匯出。
  def self.notify_data_export_failed(data_export)
    create_one(data_export.company_id, data_export.requested_by_id, "data_export_failed", data_export_payload(data_export))
  end

  def self.data_export_payload(data_export)
    { "data_export_id" => data_export.id.to_s, "scope_label" => data_export.scope_label }
  end

  def self.base_payload(reimbursement)
    {
      "reimbursement_id" => reimbursement.id.to_s,
      "description"      => reimbursement.description,
      "amount"           => reimbursement.amount.to_f,
      "category_name"    => reimbursement.category&.name
    }
  end

  # 寫入失敗只記 log、不往外拋，主流程照常完成。
  # 只接資料庫錯誤（ActiveRecord::ActiveRecordError：SQL 失敗、表不存在、連線中斷、資料驗證等）；
  # NoMethodError 這類程式錯誤照常拋出，才會被發現。
  # 用 savepoint（requires_new）包住：呼叫端若在交易裡，PostgreSQL 出錯後整個交易會卡住、
  # 後面的 SQL 全部失敗；savepoint 只撤回通知這一段，外面的交易可以繼續。不在交易裡時就是一般交易。
  def self.create_one(company_id, user_id, kind, payload)
    write(kind, "company_id=#{company_id} user_id=#{user_id}") do
      Notification.create!(company_id: company_id, user_id: user_id, kind: kind, payload: payload)
    end
  end

  def self.create_many(company_id, user_ids, kind, payload)
    rows = user_ids.map do |uid|
      {
        company_id: company_id, user_id: uid, kind: kind, payload: payload,
        created_at: Time.current, updated_at: Time.current
      }
    end
    return if rows.empty?

    write(kind, "company_id=#{company_id} user_ids=#{user_ids.join(',')}") { Notification.insert_all(rows) }
  end

  # 寄信排入背景佇列（deliver_later），不拖慢 API 回應；實際寄送在背景 job 裡，失敗不影響主流程。
  # 排入佇列本身失敗（例如佇列資料庫連不上）也只記 log。停用的人不寄。
  def self.send_mail(recipient)
    return if recipient.nil? || recipient.status_suspended?
    yield.deliver_later
  rescue StandardError => e
    Rails.logger.error("[Notifications] 寄信失敗 user_id=#{recipient&.id}: #{e.class}: #{e.message}")
    nil
  end
  private_class_method :send_mail

  def self.write(kind, target)
    Notification.transaction(requires_new: true) { yield }
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[Notifications] #{kind} 寫入失敗 #{target}: #{e.class}: #{e.message}")
    nil
  end
  private_class_method :write
end
