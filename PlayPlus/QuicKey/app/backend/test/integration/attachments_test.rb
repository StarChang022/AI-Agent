require "test_helper"

# 圖檔（docs/dev/attachments-api.md）的關鍵規則：公司間隔離、員工讀取權限、儲存空間計算、
# 永久刪除釋放實體檔案（共用檔保留）。
class AttachmentsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @coworker = create_user(company: @company)
    @account  = create_account(company: @company)

    @other       = create_company(name: "別家公司")
    @other_admin = create_user(company: @other, role: "admin")
    create_account(company: @other)
  end

  # ---- 公司間隔離 ----

  test "讀圖：別家公司的人拿不到檔案" do
    blob = upload(@admin)
    get url_path(blob, @admin)
    assert_response :ok
    assert_equal PNG, response.body

    get url_path(blob, @other_admin)
    assert_response :not_found
  end

  test "讀圖：網址被竄改或沒有 token 時 404" do
    blob = upload(@admin)
    get "#{url_path(blob, @admin)}x"
    assert_response :not_found
  end

  test "刪已存圖：別家公司的紀錄當成找不到，圖檔不受影響" do
    expense = create_expense(@admin, [ upload(@admin) ])
    blob_id = expense_attachment_ids(expense).sole

    delete "/api/expenses/#{expense.id}/attachments/#{blob_id}", headers: auth_headers(@other_admin)
    assert_response :not_found
    assert_equal [ blob_id ], expense_attachment_ids(expense)
  end

  test "刪暫存檔：別家公司、同公司別人的暫存檔都不會被刪" do
    mine   = upload(@admin)
    theirs = upload(@other_admin)
    coworkers = upload(@coworker)

    delete "/api/attachments", params: { ids: [ mine.id, theirs.id, coworkers.id ] }, headers: auth_headers(@admin)
    assert_response :no_content
    assert_not ActiveStorage::Blob.exists?(mine.id)
    assert ActiveStorage::Blob.exists?(theirs.id)
    assert ActiveStorage::Blob.exists?(coworkers.id)
  end

  test "刪暫存檔：已掛上紀錄的不會被刪" do
    blob = upload(@admin)
    create_expense(@admin, [ blob ])

    delete "/api/attachments/#{blob.id}", headers: auth_headers(@admin)
    assert_response :no_content
    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "掛上：別家公司或同公司別人上傳的檔案都不能掛" do
    [ upload(@other_admin), upload(@employee) ].each do |blob|
      assert_no_difference -> { @company.expenses.count } do
        post "/api/expenses", params: expense_params(attachment_ids: [ blob.id ]), headers: auth_headers(@admin), as: :json
      end
      assert_response :unprocessable_content
      assert_equal "ATTACHMENT_NOT_FOUND", response.parsed_body["error"]
    end
  end

  test "OCR：別家公司或同公司別人的圖檔回 attachment_not_found" do
    # 管理員本來就讀得到同公司員工的圖，所以「別人的」用員工拿同事的圖
    [ [ @admin, upload(@other_admin) ], [ @employee, upload(@coworker) ] ].each do |user, blob|
      post "/api/ocr/recognize", params: { role: "reimbursement", attachment_ids: [ blob.id ] }, headers: auth_headers(user), as: :json
      assert_response :bad_request
      assert_equal "attachment_not_found", response.parsed_body["code"]
    end
  end

  test "ActiveStorage 內建的公開讀檔路由已關閉" do
    get "/rails/active_storage/blobs/redirect/x/y"
    assert_response :not_found
  end

  # ---- 員工權限 ----

  test "員工不能刪已存圖檔" do
    expense = create_expense(@admin, [ upload(@admin) ])
    delete "/api/expenses/#{expense.id}/attachments/#{expense.attachments.blobs.sole.id}", headers: auth_headers(@employee)
    assert_response :forbidden
    assert_equal 1, expense.reload.attachments.count
  end

  test "員工只能讀自己代墊款的圖檔" do
    mine   = create_reimbursement_with(@employee, upload(@employee))
    theirs = create_reimbursement_with(@coworker, upload(@coworker))
    admin_blob = create_expense(@admin, [ upload(@admin) ]).attachments.blobs.sole

    get url_path(mine.attachments.blobs.sole, @employee)
    assert_response :ok

    get url_path(theirs.attachments.blobs.sole, @employee)
    assert_response :not_found

    get url_path(admin_blob, @employee)
    assert_response :not_found
  end

  test "代墊款核准後，員工仍讀得到自己的圖（與支出共用）；管理員讀得到" do
    reimbursement = create_reimbursement_with(@employee, upload(@employee))
    approve(reimbursement)
    blob = reimbursement.reload.expense.attachments.blobs.sole

    get url_path(blob, @employee)
    assert_response :ok
    get url_path(blob, @admin)
    assert_response :ok
  end

  # ---- 儲存空間 ----

  test "儲存空間：含垃圾桶與代墊款、共用檔只算一次、不含暫存檔" do
    general = create_expense(@admin, [ upload(@admin, "a" * 100) ])
    reimbursement = create_reimbursement_with(@employee, upload(@employee, "b" * 200))
    approve(reimbursement) # 支出與代墊款共用，只算一次
    create_expense(@admin, [ upload(@admin, "c" * 300) ]).discard! # 垃圾桶內照算
    upload(@admin, "d" * 400)                                     # 暫存檔不算
    upload(@other_admin, "e" * 500)                               # 別家公司不算

    assert_equal 600, @company.storage_bytes
    assert_equal 100, general.attachments.blobs.sole.byte_size
  end

  # ---- 永久刪除釋放實體檔案 ----

  test "刪已存圖：立即刪除實體檔案並寫稽核" do
    expense = create_expense(@admin, [ upload(@admin, "x", "a.png"), upload(@admin, "y", "b.png") ])
    blob = expense.attachments.blobs.find_by!(filename: "a.png")

    delete "/api/expenses/#{expense.id}/attachments/#{blob.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal [ "b.png" ], response.parsed_body["attachments"].map { |a| a["filename"] }
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_not blob.service.exist?(blob.key)

    log = AuditLog.where(target_id: expense.id, action: "update").sole
    assert_equal [ "a.png", "b.png" ], log.before["attachments"]
    assert_equal [ "b.png" ], log.after["attachments"]
  end

  test "垃圾桶內的紀錄不能刪圖" do
    expense = create_expense(@admin, [ upload(@admin) ])
    expense.discard!
    delete "/api/expenses/#{expense.id}/attachments/#{expense.attachments.blobs.sole.id}", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "IN_TRASH", response.parsed_body["error"]
  end

  test "永久刪除支出：實體檔案刪除" do
    expense = create_expense(@admin, [ upload(@admin) ])
    blob = expense.attachments.blobs.sole
    expense.discard!

    perform_enqueued_jobs do
      delete "/api/expenses/#{expense.id}/purge", headers: auth_headers(@admin)
    end
    assert_response :ok
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_not blob.service.exist?(blob.key)
  end

  test "代墊款產生的支出：刪圖或永久刪除只拿掉支出這邊，代墊款保留原圖" do
    reimbursement = create_reimbursement_with(@employee, upload(@employee))
    approve(reimbursement)
    expense = reimbursement.reload.expense
    blob = expense.attachments.blobs.sole

    delete "/api/expenses/#{expense.id}/attachments/#{blob.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_empty expense.reload.attachments.blobs
    assert_equal [ blob.id ], reimbursement.reload.attachments.blobs.pluck(:id)
    assert blob.service.exist?(blob.key)

    # 再掛回同一個檔案後永久刪除支出（連帶作廢代墊款）：代墊款的圖仍在
    expense.attachments.attach(blob)
    expense.discard!
    perform_enqueued_jobs do
      delete "/api/expenses/#{expense.id}/purge", params: { void_reimbursement: true, void_comment: "重複" },
                                                  headers: auth_headers(@admin)
    end
    assert_response :ok
    assert ActiveStorage::Blob.exists?(blob.id)
    assert blob.service.exist?(blob.key)
    assert_equal [ blob.id ], reimbursement.reload.attachments.blobs.pluck(:id)
  end

  test "每日排程只清超過 24 小時且未掛上的暫存檔" do
    stale, attached = travel_to(25.hours.ago) { [ upload(@admin), upload(@admin) ] }
    create_expense(@admin, [ attached ])
    fresh = upload(@admin)

    PurgeStaleUploadsJob.perform_now
    assert_not ActiveStorage::Blob.exists?(stale.id)
    assert ActiveStorage::Blob.exists?(attached.id)
    assert ActiveStorage::Blob.exists?(fresh.id)
  end

  private

  def upload(user, content = PNG, filename = "a.png")
    AttachmentFiles.create_blob!(io: StringIO.new(content), filename: filename, content_type: "image/png", user: user)
  end

  def url_path(blob, user)
    AttachmentFiles.url_for(blob, user)
  end

  def expense_params(**attrs)
    { category_id: @company.categories.of_kind("expense").active.first.id, account_id: @account.id,
      document_type: "receipt", tax_rate: "exempt_0", amount: 100, date: Date.current.iso8601 }.merge(attrs)
  end

  def create_expense(user, blobs)
    post "/api/expenses", params: expense_params(attachment_ids: blobs.map(&:id)), headers: auth_headers(user), as: :json
    assert_response :created
    Expense.find(response.parsed_body["id"])
  end

  def expense_attachment_ids(expense)
    expense.reload.attachments.blobs.pluck(:id)
  end

  def create_reimbursement_with(employee, blob)
    post "/api/reimbursements", params: {
      category_id: @company.categories.of_kind("expense").active.first.id, amount: 100,
      description: "計程車", incurred_at: Date.current.iso8601, document_type: "receipt", tax_rate: "exempt_0",
      attachment_ids: [ blob.id ], as_draft: false
    }, headers: auth_headers(employee), as: :json
    assert_response :created
    Reimbursement.find(response.parsed_body["id"])
  end

  def approve(reimbursement)
    patch "/api/reimbursements/#{reimbursement.id}/approve", params: { account_id: @account.id },
                                                             headers: auth_headers(@admin), as: :json
    assert_response :ok
  end
end
