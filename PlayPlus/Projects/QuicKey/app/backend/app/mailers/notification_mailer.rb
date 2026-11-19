class NotificationMailer < ApplicationMailer
  # 請款相關 Email 通知（docs/通知提醒.md 第 1～5 項）。由 Notifications 在寫站內通知時一起寄出。
  # 連結指到和站內通知相同的頁面（frontend/src/composables/useNotifications.ts linkFor）。
  # 金額 NT$2,000、日期 2026/10/05。

  PAYMENT_METHOD_LABELS = { "bank_transfer" => "銀行轉帳", "cash" => "現金" }.freeze

  helper_method :money, :date_label

  # 1. 新待簽核 → 管理員；連到後台審核頁並打開這筆。
  def submitted(reimbursement, recipient)
    setup(reimbursement, recipient)
    @url = "#{base_url}/admin/review?open=#{reimbursement.id}"
    mail(to: recipient.email, subject: "【Quickey】您有一筆新的請款待簽核")
  end

  # 2. 簽核通過 → 員工；預計發放日期取自連動支出，沒有時寫「尚未排定」。
  def approved(reimbursement)
    setup(reimbursement, reimbursement.employee)
    planned = reimbursement.expense&.planned_payout_date
    @planned_payout_date = planned ? date_label(planned) : "尚未排定"
    @url = front_url(reimbursement)
    mail(to: @recipient.email, subject: "【Quickey】簽核已通過")
  end

  # 3. 簽核駁回 → 員工；沒填原因就不顯示駁回原因。
  def rejected(reimbursement, comment)
    setup(reimbursement, reimbursement.employee)
    @comment = comment.to_s.strip.presence
    @url = front_url(reimbursement)
    mail(to: @recipient.email, subject: "【Quickey】簽核已駁回")
  end

  # 5. 發放完成 → 員工。
  def paid(reimbursement, paid_at)
    setup(reimbursement, reimbursement.employee)
    @payment_method = PAYMENT_METHOD_LABELS[reimbursement.payment_method]
    @paid_on = date_label(paid_at)
    @url = front_url(reimbursement)
    mail(to: @recipient.email, subject: "【Quickey】款項已發放")
  end

  # 4. 逾期未付彙整 → 管理員；每筆待付款一行，依預計發放日期由舊到新。
  def overdue_payouts(recipient, expenses, today)
    greet(recipient)
    sorted = expenses.sort_by { |e| [ e.planned_payout_date, e.created_at ] }
    @max_days = sorted.map { |e| (today - e.planned_payout_date).to_i }.max
    @lines = sorted.map do |e|
      "#{payee_name(e)} #{e.category&.name} #{money(e.amount)}（預計發放日期 #{date_label(e.planned_payout_date)}）"
    end
    @url = "#{base_url}/admin/expenses?status=pending"
    mail(to: recipient.email, subject: "【Quickey】款項逾期提醒")
  end

  private

  def setup(reimbursement, recipient)
    @reimbursement = reimbursement
    greet(recipient)
  end

  # 開頭稱呼：管理員註冊後到歡迎設定頁才補姓名，姓名空白時改用 Email。
  def greet(recipient)
    @recipient = recipient
    @name      = recipient.name.presence || recipient.email
  end

  def base_url
    Rails.configuration.frontend_base_url
  end

  def front_url(reimbursement)
    "#{base_url}/app/expenses/#{reimbursement.id}"
  end

  # 代墊款用員工姓名；一般支出用廠商名稱，沒有廠商時用說明。
  def payee_name(expense)
    if expense.source == "reimbursement" && expense.source_reimbursement
      expense.source_reimbursement.employee&.name
    else
      expense.vendor.presence || expense.note.presence || "未填廠商"
    end
  end

  # 整數不顯示小數；有小數時保留到 2 位。
  def money(amount)
    value = amount.to_d
    value = value.to_i if value == value.truncate
    "NT$#{ActiveSupport::NumberHelper.number_to_delimited(value)}"
  end

  def date_label(value)
    value = value.in_time_zone("Asia/Taipei").to_date if value.respond_to?(:in_time_zone) && !value.is_a?(Date)
    value.strftime("%Y/%m/%d")
  end
end
