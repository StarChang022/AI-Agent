require "test_helper"

# 帳戶刪除的併發：鎖定後重新確認狀態，重複送出不多寫稽核，剛被還原的帳戶不刪。
class AccountLockTest < ActionDispatch::IntegrationTest
  Account.prepend(BeforeLock)

  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @account = create_account(company: @company)
  end

  test "重複送出刪除：第二次等鎖時已在垃圾桶，回成功但不多寫稽核，刪除時間不變" do
    deleted_at = 1.hour.ago.round
    BeforeLock.hook = -> { Account.find(@account.id).update_columns(deleted_at: deleted_at) }

    delete "/api/accounts/#{@account.id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_not AuditLog.exists?(target_id: @account.id, action: "delete")
    assert_equal deleted_at, @account.reload.deleted_at
  end

  test "永久刪除等鎖時帳戶剛被還原：不刪，回 404，不寫稽核" do
    @account.discard!
    BeforeLock.hook = -> { Account.find(@account.id).update_columns(deleted_at: nil) }

    delete "/api/accounts/#{@account.id}/purge", headers: auth_headers(@admin)

    assert_response :not_found
    assert Account.exists?(@account.id)
    assert_not AuditLog.exists?(target_id: @account.id, action: "purge")
  end
end
