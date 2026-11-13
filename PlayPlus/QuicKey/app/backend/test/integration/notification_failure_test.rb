require "test_helper"

# 站內通知寫不進去時（資料庫錯誤），主要操作仍要成功並寫入資料庫（Notifications.write）。
# 用「暫時把 notifications 表改名」製造真的 PostgreSQL 錯誤（同 2026-11 正式站漏建表的狀況）：
# 這種錯誤會讓所在的交易卡住，只 rescue、沒有 savepoint 時，後續查詢全部失敗。
# 改名在測試交易裡，測試結束就還原。
class NotificationFailureTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @account  = account_for(@company)
  end

  test "通知寫入失敗時，核准請款照常完成：狀態、連動支出、稽核日誌都寫入，也沒有留下通知" do
    r = create_reimbursement(employee: @employee)

    with_notifications_table_missing do
      patch "/api/reimbursements/#{r.id}/approve", params: { account_id: @account.id }, headers: auth_headers(@admin), as: :json
      assert_response :ok
      assert_equal "approved", response.parsed_body["status"]
    end

    r.reload
    assert_equal "approved", r.status
    expense = @company.expenses.find_by!(source_ref_id: r.id)
    assert_equal r.expense_id, expense.id
    assert_equal "pending", expense.payout_status
    assert AuditLog.exists?(target_id: r.id, action: "status_change")
    assert AuditLog.exists?(target_id: expense.id, action: "create")
    assert_equal 0, Notification.count
  end

  test "通知寫入失敗時，資料匯出照常完成：檔案存好、完成信照寄" do
    expense = @company.expenses.create!(account: @account, source: "general", created_by: @admin,
      category: @company.categories.of_kind("expense").first, document_type: "receipt", tax_rate: "exempt_0",
      vendor: "全聯", amount: 100, date: Date.current)
    blob = AttachmentFiles.create_blob!(io: StringIO.new("image"), filename: "receipt.jpg", content_type: "image/jpeg", user: @admin)
    ActiveStorage::Attachment.create!(record: expense, name: AttachmentFiles::NAME, blob: blob)

    export = nil
    with_notifications_table_missing do
      assert_emails 1 do
        perform_enqueued_jobs do
          post "/api/data-exports", params: { scope: "filtered", kind: "expense" }, headers: auth_headers(@admin), as: :json
        end
      end
      assert_response :accepted
      export = DataExport.find(response.parsed_body["id"])
    end

    assert_equal "completed", export.status
    assert_equal 1, export.record_count
    assert_equal %w[attachments_zip expense_csv], export.files.map { |f| f.blob.metadata["key"] }.sort
    assert_equal 0, Notification.count
  end

  private

  def with_notifications_table_missing
    Notification.columns # 先載入欄位資訊，寫入時才會真的送出 INSERT（同正式站）
    connection = ActiveRecord::Base.connection
    connection.execute("ALTER TABLE notifications RENAME TO notifications_missing")
    yield
  ensure
    connection.execute("ALTER TABLE notifications_missing RENAME TO notifications")
  end
end
