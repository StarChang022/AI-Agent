require "test_helper"

# 支出、收入垃圾桶批次還原與永久刪除（PRD 第 18 條、docs/dev/trash-batch-api.md）：
# 部分失敗、公司隔離、作廢原因套用、筆數上限。
class TrashBatchTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @bank     = create_account(company: @company, name: "永豐", opening_month: Date.new(2026, 1, 1))
    @petty    = create_account(company: @company, name: "零用金", opening_month: Date.new(2026, 1, 1))

    @other_company = create_company(name: "別家公司")
    @other_admin   = create_user(company: @other_company, role: "admin")
  end

  test "支出批次還原：可還原的還原，其他各自列出原因" do
    ok        = trashed(general_expense)
    voided    = trashed_reimbursement_expense.tap { |e, r| void!(r) }.first
    fee       = Transfer.find(transfer).fee_expense
    delete "/api/transfers/#{fee.transfer_id}", headers: auth_headers(@admin)
    kept      = general_expense
    foreign   = trashed(general_expense(company: @other_company, by: @other_admin))

    post "/api/expenses/batch_restore", params: { ids: [ ok.id, voided.id, fee.id, kept.id, foreign.id, "not-a-uuid" ] },
      headers: auth_headers(@admin), as: :json
    assert_response :ok

    assert_equal [ ok.id ], body["succeeded"]
    assert_equal({ voided.id => "REIMBURSEMENT_VOIDED", fee.id => "TRANSFER_FEE_LOCKED", kept.id => "NOT_FOUND",
                   foreign.id => "NOT_FOUND", "not-a-uuid" => "NOT_FOUND" }, failed_codes)
    assert body["failed"].all? { |f| f["message"].present? }

    assert_not ok.reload.discarded?
    assert voided.reload.discarded?
    assert fee.reload.discarded?
    assert foreign.reload.discarded?
    assert_equal 1, AuditLog.where(action: "restore", target_type: "expense").count
  end

  test "支出批次永久刪除：作廢原因套用到來源代墊款尚可作廢的那幾筆" do
    general           = trashed(general_expense)
    first, first_r    = trashed_reimbursement_expense
    second, second_r  = trashed_reimbursement_expense
    voided, voided_r  = trashed_reimbursement_expense
    void!(voided_r)

    post "/api/expenses/batch_purge", params: { ids: [ general.id, first.id, second.id, voided.id ], void_comment: " 重複請款 " },
      headers: auth_headers(@admin), as: :json
    assert_response :ok

    assert_equal [ general.id, first.id, second.id, voided.id ], body["succeeded"]
    assert_empty body["failed"]
    assert_equal 0, Expense.where(id: [ general.id, first.id, second.id, voided.id ]).count

    [ first_r, second_r ].each do |r|
      r.reload
      assert_equal "voided", r.status
      assert_equal "重複請款", r.history.last["comment"]
      assert_nil r.expense_id
    end
    # 已作廢的那筆不再作廢一次
    assert_equal 1, AuditLog.where(target_id: voided_r.id, action: "void").count
    assert_equal 4, AuditLog.where(action: "purge", target_type: "expense").count
  end

  test "支出批次永久刪除沒填作廢原因：需作廢的列 VOID_REQUIRED，其他照刪" do
    general = trashed(general_expense)
    linked, linked_r = trashed_reimbursement_expense
    fee_zero = Transfer.find(transfer).fee_expense
    patch "/api/transfers/#{fee_zero.transfer_id}", params: { fee: 0 }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    current_fee = Transfer.find(transfer).fee_expense
    delete "/api/transfers/#{current_fee.transfer_id}", headers: auth_headers(@admin)

    post "/api/expenses/batch_purge", params: { ids: [ general.id, linked.id, fee_zero.id, current_fee.id ], void_comment: "  " },
      headers: auth_headers(@admin), as: :json
    assert_response :ok

    assert_equal [ general.id, fee_zero.id ], body["succeeded"]
    assert_equal({ linked.id => "VOID_REQUIRED", current_fee.id => "TRANSFER_FEE_LOCKED" }, failed_codes)
    assert Expense.exists?(linked.id)
    assert Expense.exists?(current_fee.id)
    assert_equal "approved", linked_r.reload.status
  end

  test "收入批次還原、永久刪除：只動本公司垃圾桶內的" do
    a = trashed(income)
    b = trashed(income)
    kept    = income
    foreign = trashed(income(company: @other_company, by: @other_admin))

    post "/api/incomes/batch_restore", params: { ids: [ a.id, kept.id, foreign.id ] }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ a.id ], body["succeeded"]
    assert_equal({ kept.id => "NOT_FOUND", foreign.id => "NOT_FOUND" }, failed_codes)
    assert_not a.reload.discarded?
    assert foreign.reload.discarded?

    post "/api/incomes/batch_purge", params: { ids: [ b.id, foreign.id ] }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ b.id ], body["succeeded"]
    assert_not Income.exists?(b.id)
    assert Income.exists?(foreign.id)
    assert_equal 1, AuditLog.where(action: "purge", target_type: "income").count
  end

  test "ids 空或超過 50 筆回 422，資料不動" do
    e = trashed(general_expense)
    ids = [ e.id ] + Array.new(50) { SecureRandom.uuid }

    %w[expenses incomes].each do |kind|
      %w[batch_restore batch_purge].each do |action|
        post "/api/#{kind}/#{action}", params: { ids: ids }, headers: auth_headers(@admin), as: :json
        assert_response :unprocessable_content
        assert_equal "TOO_MANY_IDS", body["error"]

        post "/api/#{kind}/#{action}", params: { ids: [] }, headers: auth_headers(@admin), as: :json
        assert_response :unprocessable_content
        assert_equal "IDS_REQUIRED", body["error"]
      end
    end
    assert e.reload.discarded?
  end

  test "員工不能呼叫批次 API" do
    e = trashed(general_expense)
    post "/api/expenses/batch_purge", params: { ids: [ e.id ] }, headers: auth_headers(@employee), as: :json
    assert_response :forbidden
    assert Expense.exists?(e.id)
  end

  private

  def body
    response.parsed_body
  end

  def failed_codes
    body["failed"].to_h { |f| [ f["id"], f["error"] ] }
  end

  def general_expense(company: @company, by: @admin)
    company.expenses.create!(source: "general", category: company.categories.find_by!(kind: "expense", name: "交通費"),
      account: account_for(company), created_by: by, document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
  end

  def income(company: @company, by: @admin)
    company.incomes.create!(category: company.categories.find_by!(kind: "income", name: "銷售收入"), account: account_for(company),
      created_by: by, customer: "王", document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
  end

  def trashed(record)
    record.discard!
    record
  end

  # 走核准 API 產生來源為代墊款的支出，再移到垃圾桶；回 [支出, 代墊款]。
  def trashed_reimbursement_expense
    reimbursement = create_reimbursement(employee: @employee)
    patch "/api/reimbursements/#{reimbursement.id}/approve", params: { account_id: @bank.id }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    expense = @company.expenses.find_by!(source_ref_id: reimbursement.id)
    delete "/api/expenses/#{expense.id}", headers: auth_headers(@admin)
    assert_response :ok
    [ expense, reimbursement ]
  end

  def void!(reimbursement)
    patch "/api/reimbursements/#{reimbursement.id}/void", params: { comment: "作廢" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  def transfer(fee: 15)
    post "/api/transfers", params: { from_account_id: @bank.id, to_account_id: @petty.id, amount: 5000,
                                     fee: fee, transfer_date: "2026-11-02" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body["id"]
  end
end
