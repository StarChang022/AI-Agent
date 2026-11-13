require "test_helper"

# 資金移轉（PRD 第 19 條）：新增、驗證、手續費連動、垃圾桶、永久刪除、起始月份、權限與公司隔離。
class TransfersTest < ActionDispatch::IntegrationTest
  Transfer.prepend(BeforeLock)
  Account.prepend(BeforeLock)

  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @bank    = create_account(company: @company, name: "永豐", opening_amount: 100_000, opening_month: Date.new(2026, 1, 1))
    @petty   = create_account(company: @company, name: "零用金", opening_amount: 1_000, opening_month: Date.new(2026, 3, 1))
  end

  test "新增：沒有手續費不產生支出" do
    assert_no_difference -> { @company.expenses.count } do
      post_transfer(note: "提領零用金", amount: "5000.50")
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "永豐", body.dig("from_account", "name")
    assert_equal "零用金", body.dig("to_account", "name")
    assert_equal 5000.5, body["amount"]
    assert_equal 0.0, body["fee"]
    assert_equal "2026-11-02", body["transfer_date"]
    assert_equal "提領零用金", body["note"]
    assert_nil body["fee_expense_id"]
    assert_equal @admin.id, body.dig("created_by", "id")
  end

  test "新增：手續費大於 0 產生一筆已付款支出，欄位依規格" do
    post_transfer(fee: 15)
    assert_response :created

    expense = @company.expenses.sole
    assert_equal expense.id, response.parsed_body["fee_expense_id"]
    assert_equal "transfer_fee", expense.source
    assert_equal response.parsed_body["id"], expense.transfer_id
    assert_equal Category::TRANSFER_FEE_KEY, expense.category.system_key
    assert_equal @bank.id, expense.account_id
    assert_equal Date.new(2026, 11, 2), expense.date
    assert_equal Date.new(2026, 11, 2), expense.paid_at
    assert_equal "paid", expense.payout_status
    assert_equal @admin.id, expense.paid_by_id
    assert_equal @admin.id, expense.created_by_id
    assert_equal "receipt", expense.document_type
    assert_equal "exempt_0", expense.tax_rate
    assert_equal 15, expense.amount
    assert_equal 15, expense.pre_tax_amt
    assert_equal 0, expense.tax_amt
    assert_equal "資金移轉手續費", expense.note
    assert_equal 0, @admin.notifications.count
  end

  test "手續費計入損益，移轉金額不計入" do
    post_transfer(amount: 5000, fee: 15)

    get "/api/reports/profit-loss", params: { from: "2026-11-01", to: "2026-11-30" }, headers: auth_headers(@admin)
    assert_equal 15.0, response.parsed_body.dig("total", "expense")
    assert_equal 0.0, response.parsed_body.dig("total", "income")
  end

  test "驗證錯誤：代碼與 sides" do
    cases = {
      { from_account_id: nil } => [ "ACCOUNT_REQUIRED", [ "from" ] ],
      { to_account_id: "" } => [ "ACCOUNT_REQUIRED", [ "to" ] ],
      { from_account_id: nil, to_account_id: nil } => [ "ACCOUNT_REQUIRED", %w[from to] ],
      { to_account_id: "not-a-uuid" } => [ "ACCOUNT_REQUIRED", [ "to" ] ],
      { to_account_id: @bank.id } => [ "SAME_ACCOUNT", %w[from to] ],
      { to_account_id: SecureRandom.uuid } => [ "ACCOUNT_NOT_FOUND", [ "to" ] ],
      { amount: 0 } => [ "INVALID_AMOUNT", nil ],
      { amount: -1 } => [ "INVALID_AMOUNT", nil ],
      { amount: nil } => [ "INVALID_AMOUNT", nil ],
      { amount: "abc" } => [ "INVALID_AMOUNT", nil ],
      { amount: "NaN" } => [ "INVALID_AMOUNT", nil ],
      { amount: "1.234" } => [ "INVALID_AMOUNT", nil ],
      { amount: "10000000000" } => [ "INVALID_AMOUNT", nil ],
      { fee: -1 } => [ "INVALID_FEE", nil ],
      { fee: "1.234" } => [ "INVALID_FEE", nil ],
      { fee: "abc" } => [ "INVALID_FEE", nil ],
      { transfer_date: nil } => [ "INVALID_TRANSFER_DATE", nil ],
      { transfer_date: "2026-02-30" } => [ "INVALID_TRANSFER_DATE", nil ]
    }

    cases.each do |attrs, (code, sides)|
      assert_no_difference -> { @company.transfers.count } do
        post_transfer(**attrs)
      end
      assert_response :unprocessable_content, attrs.inspect
      assert_equal code, response.parsed_body["error"], attrs.inspect
      if sides
        assert_equal sides, response.parsed_body["sides"], attrs.inspect
      else
        assert_not response.parsed_body.key?("sides"), attrs.inspect
      end
      assert response.parsed_body["message"].present?
    end
  end

  test "手續費沒帶或空字串視為 0" do
    post_transfer(fee: "")
    assert_response :created
    assert_equal 0.0, response.parsed_body["fee"]
  end

  test "帳戶在垃圾桶不可使用" do
    @petty.discard!
    post_transfer
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    assert_equal [ "to" ], response.parsed_body["sides"]
  end

  test "移轉日期早於起始月份不可存，指出是哪個帳戶；當月 1 日可以" do
    post_transfer(transfer_date: "2026-02-28")
    assert_response :unprocessable_content
    assert_equal "TRANSFER_DATE_BEFORE_OPENING", response.parsed_body["error"]
    assert_equal [ "to" ], response.parsed_body["sides"]
    assert_includes response.parsed_body["message"], "「零用金」（2026-03）"

    post_transfer(transfer_date: "2025-12-31")
    assert_equal %w[from to], response.parsed_body["sides"]
    assert_includes response.parsed_body["message"], "「永豐」（2026-01）、「零用金」（2026-03）"

    post_transfer(transfer_date: "2026-03-01")
    assert_response :created
  end

  test "帳戶名稱含特殊符號，錯誤訊息照常顯示" do
    @petty.update!(name: "100%{a}")
    post_transfer(transfer_date: "2026-02-28")
    assert_equal "TRANSFER_DATE_BEFORE_OPENING", response.parsed_body["error"]
    assert_includes response.parsed_body["message"], "100%{a}"
  end

  test "資料庫的 CHECK 約束：繞過 model 也寫不進去" do
    transfer = @company.transfers.find(transfer!)

    {
      { amount: 0 }    => "transfers_amount_positive",
      { amount: -1 }   => "transfers_amount_positive",
      { fee: -0.01 }   => "transfers_fee_not_negative",
      { to_account_id: @bank.id } => "transfers_accounts_differ"
    }.each do |attrs, constraint|
      error = assert_raises(ActiveRecord::CheckViolation, attrs.inspect) do
        Transfer.transaction(requires_new: true) { transfer.update_columns(attrs) }
      end
      assert_includes error.message, constraint
      transfer.reload
    end

    transfer.update_columns(fee: 0)
    assert_equal 0, transfer.reload.fee
  end

  test "憑證同支出的結構，單筆回傳、列表不回" do
    blob = AttachmentFiles.create_blob!(io: StringIO.new("png"), filename: "a.png", content_type: "image/png", user: @admin)
    post_transfer(attachment_ids: [ blob.id ])
    assert_response :created
    id = response.parsed_body["id"]

    get "/api/transfers/#{id}", headers: auth_headers(@admin)
    assert_equal "a.png", response.parsed_body["attachments"].sole["filename"]

    get "/api/transfers", headers: auth_headers(@admin)
    assert_not response.parsed_body["data"].sole.key?("attachments")
  end

  test "列表：分頁、依日期新到舊，可依日期區間、轉出、轉入篩選" do
    third = create_account(company: @company, name: "第三帳戶", opening_month: Date.new(2026, 1, 1))
    a = transfer!(transfer_date: "2026-05-01")
    b = transfer!(transfer_date: "2026-06-01", from_account_id: @petty.id, to_account_id: @bank.id)
    c = transfer!(transfer_date: "2026-07-01", to_account_id: third.id)

    assert_equal [ c, b, a ], list
    assert_equal [ a ], list(page: 2, per_page: 2)
    assert_equal({ "total" => 3, "page" => 2, "page_size" => 2 }, response.parsed_body["meta"])
    assert_equal [ c, b ], list(date_from: "2026-06-01")
    assert_equal [ b, a ], list(date_to: "2026-06-30")
    assert_equal [ b ], list(from_account_id: @petty.id)
    assert_equal [ c ], list(to_account_id: third.id)
    assert_equal [ c, a ], list(from_account_id: @bank.id)
    assert_equal [ c, b, a ], list(date_from: "garbage")
  end

  test "編輯：同步手續費支出的金額、日期、帳戶" do
    id = transfer!(fee: 15)
    expense = @company.expenses.sole

    patch_transfer(id, fee: 30, transfer_date: "2026-10-05", from_account_id: @petty.id, to_account_id: @bank.id)
    assert_response :ok
    expense.reload
    assert_equal 30, expense.amount
    assert_equal 30, expense.pre_tax_amt
    assert_equal Date.new(2026, 10, 5), expense.date
    assert_equal Date.new(2026, 10, 5), expense.paid_at
    assert_equal @petty.id, expense.account_id
    assert_equal @admin.id, expense.paid_by_id
  end

  test "編輯：只改備註不寫手續費支出的稽核" do
    id = transfer!(fee: 15)
    expense = @company.expenses.sole

    assert_no_difference -> { AuditLog.where(target_id: expense.id).count } do
      patch_transfer(id, note: "新備註")
    end
    assert_response :ok
  end

  test "手續費改為 0 進垃圾桶並清空；再填手續費產生新的一筆，舊的留在垃圾桶" do
    id = transfer!(fee: 15)
    first = @company.expenses.sole

    patch_transfer(id, fee: 0)
    assert_nil response.parsed_body["fee_expense_id"]
    assert first.reload.discarded?
    assert_equal id, first.transfer_id

    patch_transfer(id, fee: 20)
    second_id = response.parsed_body["fee_expense_id"]
    assert_not_equal first.id, second_id
    assert first.reload.discarded?
    assert_nil @company.expenses.find(second_id).deleted_at
    assert_equal 2, @company.expenses.where(transfer_id: id).count
  end

  test "編輯：日期早於起始月份不可存，手續費支出不動；垃圾桶內的回 404" do
    id = transfer!(fee: 15)

    patch_transfer(id, transfer_date: "2026-02-01", fee: 99)
    assert_response :unprocessable_content
    assert_equal "TRANSFER_DATE_BEFORE_OPENING", response.parsed_body["error"]
    assert_equal 15, @company.expenses.sole.amount

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    patch_transfer(id, note: "改")
    assert_response :not_found
  end

  test "刪除、還原：已付款的手續費支出一併進出垃圾桶" do
    id = transfer!(fee: 15)
    expense = @company.expenses.sole
    assert_equal "paid", expense.payout_status

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    assert_response :ok
    assert expense.reload.discarded?
    assert_equal expense.id, @company.transfers.find(id).fee_expense_id

    get "/api/transfers", params: { discarded: true }, headers: auth_headers(@admin)
    row = response.parsed_body["data"].sole
    assert_equal id, row["id"]
    assert_equal @admin.id, row.dig("deleted_by", "id")

    get "/api/transfers/#{id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal @admin.id, response.parsed_body.dig("deleted_by", "id")

    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil expense.reload.deleted_at
    assert_equal "paid", expense.payout_status
  end

  test "還原只還原目前對應的手續費，手續費改為 0 留下的舊支出不動" do
    id = transfer!(fee: 15)
    old = @company.expenses.sole
    patch_transfer(id, fee: 0)
    patch_transfer(id, fee: 20)
    current = @company.transfers.find(id).fee_expense

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)

    assert_nil current.reload.deleted_at
    assert old.reload.discarded?
  end

  test "永久刪除：含手續費改為 0 留下的支出全部移除，只限垃圾桶內" do
    id = transfer!(fee: 15)
    patch_transfer(id, fee: 0)
    patch_transfer(id, fee: 20)
    assert_equal 2, @company.expenses.count

    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)
    assert_response :not_found

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)
    assert_response :ok
    assert_not Transfer.exists?(id)
    assert_equal 0, @company.expenses.count
  end

  test "手續費類別不受一般支出影響：可選給一般支出，移轉永久刪除不動一般支出" do
    id = transfer!(fee: 15)
    category = @company.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY)
    general = @company.expenses.create!(source: "general", category: category, account: @bank, created_by: @admin,
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)

    assert Expense.exists?(general.id)
  end

  test "起始月份調晚：轉出、轉入都擋，回筆數與最早日期，不寫入" do
    transfer!(transfer_date: "2026-05-10")
    transfer!(transfer_date: "2026-06-10")

    [ @bank, @petty ].each do |account|
      patch "/api/accounts/#{account.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json
      assert_response :conflict
      assert_equal "OPENING_MONTH_AFTER_TRANSFER", response.parsed_body["error"]
      assert_equal 1, response.parsed_body["transfer_count"]
      assert_equal "2026-05-10", response.parsed_body["earliest_transfer_date"]
      assert_includes response.parsed_body["message"], "2026-05-10"
    end
    assert_equal Date.new(2026, 1, 1), @bank.reload.opening_month
    assert_not AuditLog.exists?(target_id: @bank.id, action: "update")

    patch "/api/accounts/#{@bank.id}", params: { opening_month: "2026-05" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  test "起始月份往前調、只改名稱不受移轉影響" do
    transfer!(transfer_date: "2026-05-10")

    patch "/api/accounts/#{@petty.id}", params: { opening_month: "2026-02", name: "零用金二" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal Date.new(2026, 2, 1), @petty.reload.opening_month
  end

  test "收支不受移轉的起始月份限制" do
    @company.expenses.create!(source: "general", category: @company.categories.of_kind("expense").active.first, account: @bank,
      created_by: @admin, document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.new(2026, 2, 1),
      payout_status: "paid", paid_at: Date.new(2026, 2, 1))

    patch "/api/accounts/#{@bank.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  test "改完移轉日期後可以調起始月份" do
    id = transfer!(transfer_date: "2026-05-10")
    patch "/api/accounts/#{@bank.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json
    assert_response :conflict

    patch_transfer(id, transfer_date: "2026-06-01")
    assert_response :ok

    patch "/api/accounts/#{@bank.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  test "垃圾桶內的移轉不擋調整，還原時被擋並指出帳戶；調回去後可還原" do
    id = transfer!(transfer_date: "2026-05-10", fee: 15)
    expense = @company.expenses.sole
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    patch "/api/accounts/#{@petty.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "TRANSFER_DATE_BEFORE_OPENING", response.parsed_body["error"]
    assert_equal [ "to" ], response.parsed_body["sides"]
    assert_includes response.parsed_body["message"], "零用金"
    assert @company.transfers.find(id).discarded?
    assert expense.reload.discarded?
    assert_not AuditLog.exists?(target_id: id, action: "restore")

    patch "/api/accounts/#{@petty.id}", params: { opening_month: "2026-05" }, headers: auth_headers(@admin), as: :json
    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil expense.reload.deleted_at
  end

  test "日期已早於起始月份的垃圾桶移轉可以永久刪除" do
    id = transfer!(transfer_date: "2026-05-10", fee: 15)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    patch "/api/accounts/#{@petty.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json

    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)
    assert_response :ok
  end

  test "帳戶調整等鎖時剛好有移轉存檔：鎖定後才查移轉，一樣擋下" do
    BeforeLock.hook = -> {
      @company.transfers.create!(from_account: @bank, to_account: @petty, amount: 100, transfer_date: "2026-05-10", created_by: @admin)
    }

    patch "/api/accounts/#{@bank.id}", params: { opening_month: "2026-06" }, headers: auth_headers(@admin), as: :json

    assert_response :conflict
    assert_equal Date.new(2026, 1, 1), @bank.reload.opening_month
  end

  test "移轉存檔鎖住兩個帳戶，查詢依 id 排序" do
    sql = []
    callback = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?("FOR SHARE") && payload[:sql].include?("accounts") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { post_transfer }

    assert_response :created
    assert(sql.any? { |q| q.match?(/ORDER BY "accounts"."id" ASC.*FOR SHARE/) })
  end

  test "impact：回擋下調整的移轉筆數與最早日期，不算垃圾桶，不計入收支筆數" do
    transfer!(transfer_date: "2026-05-10")
    transfer!(transfer_date: "2026-04-10", from_account_id: @petty.id, to_account_id: @bank.id)
    delete "/api/transfers/#{transfer!(transfer_date: "2026-03-10")}", headers: auth_headers(@admin)

    get "/api/accounts/#{@bank.id}/opening-month-impact", params: { opening_month: "2026-08" }, headers: auth_headers(@admin)

    assert_response :ok
    body = response.parsed_body
    assert_equal 2, body["blocking_transfer_count"]
    assert_equal "2026-04-10", body["earliest_transfer_date"]
    assert_equal 0, body["outside_cash_flow_count"]
    assert_equal({ "expenses" => 0, "incomes" => 0 }, body["outside_cash_flow"])
  end

  test "帳戶被移轉引用不可刪除，轉出、轉入、垃圾桶內都算" do
    id = transfer!
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    [ @bank, @petty ].each do |account|
      delete "/api/accounts/#{account.id}", headers: auth_headers(@admin)
      assert_response :conflict
      assert_equal "ACCOUNT_IN_USE", response.parsed_body["error"]
      assert_equal 1, response.parsed_body.dig("references", "transfers")
      assert_includes response.parsed_body["message"], "1 筆資金移轉"
    end

    get "/api/accounts", headers: auth_headers(@admin)
    row = response.parsed_body["data"].find { |a| a["id"] == @bank.id }
    assert_equal false, row["deletable"]
  end

  test "重複送出刪除：第二次等鎖時已在垃圾桶，不多寫稽核" do
    id = transfer!(fee: 15)
    deleted_at = 1.hour.ago.round
    BeforeLock.hook = -> { Transfer.find(id).update_columns(deleted_at: deleted_at) }

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    assert_response :ok
    assert_not AuditLog.exists?(target_id: id, action: "delete")
    assert_nil @company.expenses.sole.deleted_at
  end

  test "編輯等鎖時移轉剛被刪除：回 404，不寫入" do
    id = transfer!
    BeforeLock.hook = -> { Transfer.find(id).update_columns(deleted_at: Time.current) }

    patch_transfer(id, note: "改")

    assert_response :not_found
    assert_nil Transfer.find(id).note
  end

  test "永久刪除等鎖時移轉剛被還原：不刪，回 404" do
    id = transfer!
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    BeforeLock.hook = -> { Transfer.find(id).update_columns(deleted_at: nil) }

    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)

    assert_response :not_found
    assert Transfer.exists?(id)
  end

  test "稽核：新增、編輯、刪除、還原、永久刪除，帳戶有名稱" do
    id = transfer!(note: "第一次", fee: 15)
    create_log = AuditLog.find_by!(target_type: "transfer", target_id: id, action: "create")
    assert_equal "永豐", create_log.after["from_account_name"]
    assert_equal "零用金", create_log.after["to_account_name"]
    assert_equal 15.0, create_log.after["fee"]
    assert_equal "2026-11-02", create_log.after["transfer_date"]

    third = create_account(company: @company, name: "第三帳戶", opening_month: Date.new(2026, 1, 1))
    patch_transfer(id, to_account_id: third.id, note: "第二次")
    update_log = AuditLog.find_by!(target_type: "transfer", target_id: id, action: "update")
    assert_equal "零用金", update_log.before["to_account_name"]
    assert_equal "第三帳戶", update_log.after["to_account_name"]
    assert_equal "第二次", update_log.after["note"]
    assert_not update_log.after.key?("amount")

    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)

    assert_equal %w[create delete delete purge restore update],
                 AuditLog.where(target_type: "transfer", target_id: id).pluck(:action).sort
    assert AuditLog.find_by!(target_type: "transfer", target_id: id, action: "purge").before["amount"]

    get "/api/audit-logs/history", params: { target_type: "transfer", target_id: id }, headers: auth_headers(@admin)
    assert_response :ok
    assert_equal 6, response.parsed_body.size
  end

  test "稽核：手續費支出每筆異動都帶 via" do
    id = transfer!(fee: 15)
    expense = @company.expenses.sole
    patch_transfer(id, fee: 30)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    patch_transfer(id, fee: 0)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)
    delete "/api/transfers/#{id}/purge", headers: auth_headers(@admin)

    logs = AuditLog.where(target_type: "expense", target_id: expense.id)
    assert_equal %w[create delete delete purge restore update], logs.map(&:action).sort
    logs.each { |log| assert_equal "transfer_fee", (log.after || log.before)["via"], log.action }
  end

  test "員工不可使用" do
    id = transfer!
    employee = create_user(company: @company, role: "employee")
    headers = auth_headers(employee)

    get "/api/transfers", headers: headers
    assert_response :forbidden
    get "/api/transfers/#{id}", headers: headers
    assert_response :forbidden
    post "/api/transfers", params: transfer_params, headers: headers, as: :json
    assert_response :forbidden
    patch "/api/transfers/#{id}", params: { note: "x" }, headers: headers, as: :json
    assert_response :forbidden
    delete "/api/transfers/#{id}", headers: headers
    assert_response :forbidden
    patch "/api/transfers/#{id}/restore", headers: headers
    assert_response :forbidden
    delete "/api/transfers/#{id}/purge", headers: headers
    assert_response :forbidden
  end

  test "公司隔離：別家的移轉當成找不到，別家的帳戶不可使用" do
    id = transfer!
    other_company = create_company(name: "別家公司")
    other_admin   = create_user(company: other_company, role: "admin")
    headers = auth_headers(other_admin)
    other_account = create_account(company: other_company, opening_month: Date.new(2026, 1, 1))

    get "/api/transfers", headers: headers
    assert_empty response.parsed_body["data"]
    get "/api/transfers/#{id}", headers: headers
    assert_response :not_found
    patch "/api/transfers/#{id}", params: { note: "x" }, headers: headers, as: :json
    assert_response :not_found
    delete "/api/transfers/#{id}", headers: headers
    assert_response :not_found
    patch "/api/transfers/#{id}/restore", headers: headers
    assert_response :not_found
    delete "/api/transfers/#{id}/purge", headers: headers
    assert_response :not_found
    assert_nil Transfer.find(id).deleted_at

    post_transfer(to_account_id: other_account.id)
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    patch_transfer(id, from_account_id: other_account.id)
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
  end

  private

  def transfer_params(**attrs)
    { from_account_id: @bank.id, to_account_id: @petty.id, amount: 5000, transfer_date: "2026-11-02" }.merge(attrs)
  end

  def post_transfer(**attrs)
    post "/api/transfers", params: transfer_params(**attrs), headers: auth_headers(@admin), as: :json
  end

  def patch_transfer(id, **attrs)
    patch "/api/transfers/#{id}", params: attrs, headers: auth_headers(@admin), as: :json
  end

  def transfer!(**attrs)
    post_transfer(**attrs)
    assert_response :created
    response.parsed_body["id"]
  end

  def list(**query)
    get "/api/transfers", params: query, headers: auth_headers(@admin)
    response.parsed_body["data"].map { |t| t["id"] }
  end
end
