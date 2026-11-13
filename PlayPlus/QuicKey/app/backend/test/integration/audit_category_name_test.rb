require "test_helper"

# 改類別時，「更新」稽核紀錄的 before / after 要一起記類別名稱，歷程才不用顯示 UUID。
class AuditCategoryNameTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "改支出類別，稽核紀錄的 before / after 有新舊類別名稱" do
    old_cat, new_cat = @company.categories.where(kind: "expense").order(:sort_order).first(2)
    expense = @company.expenses.create!(
      account: account_for(@company),
      source: "general", created_by: @admin, category: old_cat,
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current
    )

    patch "/api/expenses/#{expense.id}", params: { category_id: new_cat.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    log = AuditLog.where(target_id: expense.id, action: "update").sole
    assert_equal old_cat.name, log.before["category_name"]
    assert_equal new_cat.name, log.after["category_name"]
    assert_equal old_cat.id, log.before["category_id"]
    assert_equal new_cat.id, log.after["category_id"]
  end
end
