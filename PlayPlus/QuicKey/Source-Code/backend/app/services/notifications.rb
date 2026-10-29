module Notifications
  # 代墊款相關事件觸發站內通知的統一入口（docs/通知提醒.md）。
  # 各業務 controller 於狀態轉移成功後呼叫對應方法，payload 以 snake_case 儲存，
  # 前端 api/service.ts 會自動轉為 camelCase。失敗不中斷主流程（通知屬非關鍵旁路）。

  # 1. 新待簽核：員工送出 → 通知公司所有 admin。
  # admin 自提時排除自己；若公司只有一名 admin 自提則不通知任何人（避免自己通知自己）。
  def self.notify_submitted(reimbursement)
    actor     = reimbursement.employee
    admin_ids = reimbursement.company.users.where(role: "admin").where.not(id: actor.id).pluck(:id)
    return if admin_ids.empty?

    payload = {
      "reimbursement_id" => reimbursement.id.to_s,
      "actor_name"       => actor.name,
      "description"      => reimbursement.description,
      "amount"           => reimbursement.amount.to_f,
      "category_name"    => reimbursement.category&.name
    }

    create_many(reimbursement.company_id, admin_ids, "reimbursement_submitted", payload)
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
  end

  # 3. 簽核駁回：admin 駁回 → 通知員工本人（含駁回原因，可空）。
  def self.notify_rejected(reimbursement, comment:)
    create_one(
      reimbursement.company_id,
      reimbursement.employee_id,
      "reimbursement_rejected",
      base_payload(reimbursement).merge("comment" => comment.to_s)
    )
  end

  # 4. 逾期未付：排程器每天掃一次，將當前仍 pending 且 planned_payout_date 已過期的
  # 支出聚合通知該公司全部 admin。payload：
  #   overdue_count 筆數 / max_days 最大逾期天數 / expense_ids 便於前端 deeplink。
  # expenses 空則不發；呼叫端（Job）應預先過濾好當前 company 範圍。
  def self.notify_overdue_payouts(company, expenses, today: Time.zone.today)
    return if expenses.empty?

    admin_ids = company.users.where(role: "admin").pluck(:id)
    return if admin_ids.empty?

    max_days = expenses.map { |e| (today - e.planned_payout_date).to_i }.max
    payload = {
      "overdue_count" => expenses.size,
      "max_days"      => max_days,
      "expense_ids"   => expenses.map { |e| e.id.to_s }
    }

    create_many(company.id, admin_ids, "payout_overdue", payload)
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
  end

  def self.base_payload(reimbursement)
    {
      "reimbursement_id" => reimbursement.id.to_s,
      "description"      => reimbursement.description,
      "amount"           => reimbursement.amount.to_f,
      "category_name"    => reimbursement.category&.name
    }
  end

  def self.create_one(company_id, user_id, kind, payload)
    Notification.create!(company_id: company_id, user_id: user_id, kind: kind, payload: payload)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[Notifications] skip #{kind} user_id=#{user_id}: #{e.message}")
  end

  def self.create_many(company_id, user_ids, kind, payload)
    rows = user_ids.map do |uid|
      {
        company_id: company_id, user_id: uid, kind: kind, payload: payload,
        created_at: Time.current, updated_at: Time.current
      }
    end
    Notification.insert_all(rows) if rows.any?
  end
end
