require "test_helper"

# 請款相關 Email 通知（docs/通知提醒.md 第 1～5 項）：收件人和站內通知相同、停用的人不寄、
# 管理員自己送出的不寄、寄信失敗不影響主流程、逾期信只列自己公司的款項。
class NotificationMailTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # 讓排入寄信佇列時失敗，用來驗證主流程不受影響。
  module FailingDeliverLater
    mattr_accessor :enabled, instance_accessor: false

    def deliver_later(...)
      raise "佇列連不上" if FailingDeliverLater.enabled
      super
    end
  end
  ActionMailer::MessageDelivery.prepend(FailingDeliverLater)

  setup do
    ActionMailer::Base.deliveries.clear
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @account  = account_for(@company)
  end

  teardown do
    FailingDeliverLater.enabled = false
  end

  test "新待簽核寄給管理員，連到後台審核頁" do
    r = create_reimbursement(employee: @employee)
    perform_enqueued_jobs { Notifications.notify_submitted(r) }

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ @admin.email ], mail.to
    assert_equal "【Quickey】您有一筆新的請款待簽核", mail.subject
    text = mail.text_part.body.to_s
    assert_includes text, "申請人：#{@employee.name}"
    assert_includes text, "金額：NT$100"
    assert_includes text, "/admin/review?open=#{r.id}"
  end

  test "管理員自己送出的請款不寄信" do
    r = create_reimbursement(employee: @admin)
    perform_enqueued_jobs { Notifications.notify_submitted(r) }
    assert_empty ActionMailer::Base.deliveries
  end

  test "核准、發放寄給員工本人，連到前台這筆請款" do
    r = create_reimbursement(employee: @employee)
    perform_enqueued_jobs do
      patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
    end
    assert_response :ok

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ [ @employee.email ], "【Quickey】簽核已通過" ], [ mail.to, mail.subject ]
    planned = @company.expenses.find_by!(source_ref_id: r.id).planned_payout_date
    assert_includes mail.text_part.body.to_s, "預計發放日期：#{planned.strftime('%Y/%m/%d')}"
    assert_includes mail.text_part.body.to_s, "/app/expenses/#{r.id}"

    ActionMailer::Base.deliveries.clear
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    perform_enqueued_jobs do
      patch "/api/expenses/#{expense.id}/pay", params: { payment_method: "cash", paid_at: "2026-10-05" },
        headers: auth_headers(@admin), as: :json
    end
    assert_response :ok

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ [ @employee.email ], "【Quickey】款項已發放" ], [ mail.to, mail.subject ]
    assert_includes mail.text_part.body.to_s, "發放方式：現金"
    assert_includes mail.text_part.body.to_s, "發放日期：2026/10/05"
  end

  test "駁回寄給員工本人，附駁回原因" do
    r = create_reimbursement(employee: @employee)
    perform_enqueued_jobs do
      patch "/api/reimbursements/#{r.id}/reject", params: { comment: "缺發票" }, headers: auth_headers(@admin), as: :json
    end
    assert_response :ok

    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ [ @employee.email ], "【Quickey】簽核已駁回" ], [ mail.to, mail.subject ]
    assert_includes mail.text_part.body.to_s, "駁回原因：缺發票"
  end

  test "停用的員工不寄信，站內通知照寫" do
    r = create_reimbursement(employee: @employee)
    @employee.update!(status: "suspended")

    perform_enqueued_jobs do
      patch "/api/reimbursements/#{r.id}/reject", params: { comment: "缺發票" }, headers: auth_headers(@admin), as: :json
    end
    assert_response :ok
    assert_empty ActionMailer::Base.deliveries
    assert @employee.notifications.exists?(kind: "reimbursement_rejected")
  end

  test "寄信失敗時核准照常完成" do
    r = create_reimbursement(employee: @employee)
    FailingDeliverLater.enabled = true

    patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "approved", r.reload.status
    assert @company.expenses.exists?(source_ref_id: r.id)
    assert @employee.notifications.exists?(kind: "reimbursement_approved")
    assert_no_enqueued_emails
  end

  test "逾期信每家公司寄給自己的管理員，只列自己公司的款項" do
    today = Time.find_zone!("Asia/Taipei").today
    overdue_expense(@company, vendor: "福華文具行", amount: 15_000, planned: today - 3)
    overdue_expense(@company, vendor: nil, note: "影印紙", amount: 2_000, planned: today - 1)
    other       = create_company(name: "他公司")
    other_admin = create_user(company: other, role: "admin")
    overdue_expense(other, vendor: "他公司廠商", amount: 999, planned: today - 2)

    perform_enqueued_jobs { NotifyOverduePayoutsJob.perform_now }

    mine = ActionMailer::Base.deliveries.find { |m| m.to == [ @admin.email ] }.text_part.body.to_s
    assert_includes mine, "有待付款已逾期 3 天"
    assert_includes mine, "福華文具行 #{category_name(@company)} NT$15,000（預計發放日期 #{(today - 3).strftime('%Y/%m/%d')}）"
    assert_includes mine, "影印紙 #{category_name(@company)} NT$2,000"
    assert_includes mine, "/admin/expenses?status=pending"
    assert_not_includes mine, "他公司廠商"

    theirs = ActionMailer::Base.deliveries.find { |m| m.to == [ other_admin.email ] }.text_part.body.to_s
    assert_includes theirs, "他公司廠商"
    assert_not_includes theirs, "福華文具行"
  end

  private

  def category_name(company)
    company.categories.of_kind("expense").active.first.name
  end

  def overdue_expense(company, vendor:, amount:, planned:, note: nil)
    company.expenses.create!(
      account: account_for(company), source: "general", created_by: company.users.first,
      category: company.categories.of_kind("expense").active.first, document_type: "receipt", tax_rate: "exempt_0",
      vendor: vendor, note: note, amount: amount, date: planned, planned_payout_date: planned
    )
  end
end
