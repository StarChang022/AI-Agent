require "test_helper"

# 垃圾桶內的支出、收入：單筆查詢查得到（給詳情抽屜唯讀顯示，含刪除時間、操作人、圖檔），
# 仍限本公司；會改資料的 API 一律查不到（404），刪圖檔回 IN_TRASH，紀錄不被改動。
class TrashDetailTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @account = account_for(@company)

    @expense = @company.expenses.create!(source: "general", category: @company.categories.of_kind("expense").active.first,
      account: @account, created_by: @admin, document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current)
    @income = @company.incomes.create!(created_by: @admin, category: @company.categories.of_kind("income").active.first,
      account: @account, customer: "王", document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    @attachments = { @expense => attach(@expense), @income => attach(@income) }

    delete "/api/expenses/#{@expense.id}", headers: auth_headers(@admin)
    assert_response :ok
    delete "/api/incomes/#{@income.id}", headers: auth_headers(@admin)
    assert_response :ok
  end

  test "垃圾桶的支出、收入查得到：刪除時間、操作人，圖檔網址打得開" do
    each_record do |path, record|
      get path, headers: auth_headers(@admin)
      assert_response :ok
      body = response.parsed_body
      assert_equal record.reload.deleted_at.iso8601, body["deleted_at"]
      assert_equal({ "id" => @admin.id, "name" => @admin.name }, body["deleted_by"])

      file = body["attachments"].sole
      assert_equal @attachments[record].blob_id, file["id"]
      get file["url"]
      assert_response :ok
      get file["url"], params: { download: 1 }
      assert_response :ok
      assert_match "attachment", response.headers["Content-Disposition"]
    end
  end

  test "不在垃圾桶的支出 deleted_at、deleted_by 為 null" do
    expense = @company.expenses.create!(source: "general", category: @company.categories.of_kind("expense").active.first,
      account: @account, created_by: @admin, document_type: "receipt", tax_rate: "exempt_0", amount: 1, date: Date.current)
    get "/api/expenses/#{expense.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_nil response.parsed_body["deleted_at"]
    assert_nil response.parsed_body["deleted_by"]
  end

  test "別家公司的垃圾桶紀錄查不到" do
    other_admin = create_user(company: create_company(name: "他公司"), role: "admin")
    each_record do |path, _record|
      get path, headers: auth_headers(other_admin)
      assert_response :not_found
    end
  end

  test "垃圾桶紀錄打會改資料的 API 回 404，刪圖檔回 IN_TRASH，紀錄不變" do
    headers = auth_headers(@admin)
    before = [ @expense.reload.attributes, @income.reload.attributes ]

    {
      [ :patch,  "/api/expenses/#{@expense.id}" ]                    => { note: "改" },
      [ :delete, "/api/expenses/#{@expense.id}" ]                    => {},
      [ :patch,  "/api/expenses/#{@expense.id}/pay" ]                => {},
      [ :patch,  "/api/expenses/#{@expense.id}/revert-pay" ]         => {},
      [ :patch,  "/api/expenses/#{@expense.id}/adjust-payout-date" ] => { date: "2026-12-01" },
      [ :patch,  "/api/incomes/#{@income.id}" ]                      => { note: "改" },
      [ :delete, "/api/incomes/#{@income.id}" ]                      => {},
      [ :patch,  "/api/incomes/#{@income.id}/collect" ]              => {},
      [ :patch,  "/api/incomes/#{@income.id}/revert-collect" ]       => {}
    }.each do |(verb, path), params|
      send(verb, path, params: params, headers: headers, as: :json)
      assert_response :not_found, "#{verb} #{path}"
    end

    each_record do |path, record|
      delete "#{path}/attachments/#{@attachments[record].id}", headers: headers
      assert_response :conflict
      assert_equal "IN_TRASH", response.parsed_body["error"]
    end

    assert_equal before, [ @expense.reload.attributes, @income.reload.attributes ]
    assert_equal 1, @expense.attachments.count
    assert_equal 1, @income.attachments.count
  end

  private

  def each_record
    { "/api/expenses/#{@expense.id}" => @expense, "/api/incomes/#{@income.id}" => @income }.each { |path, record| yield path, record }
  end

  def attach(record)
    blob = AttachmentFiles.create_blob!(io: StringIO.new("image"), filename: "receipt.jpg", content_type: "image/jpeg", user: @admin)
    ActiveStorage::Attachment.create!(record: record, name: AttachmentFiles::NAME, blob: blob)
  end
end
