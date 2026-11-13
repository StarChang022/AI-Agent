require "test_helper"
require "csv"
require "zip"

# 資料匯出（docs/dev/data-export-api.md）的關鍵規則：員工不可用、公司間隔離、垃圾桶排除、
# 代墊款排除草稿、過期拒絕下載、每次發起寫一筆稽核日誌。
class DataExportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @account  = account_for(@company)

    @other_company  = create_company(name: "別家公司")
    @other_admin    = create_user(company: @other_company, role: "admin")
    @other_employee = create_user(company: @other_company)
  end

  # ---- 角色權限 ----

  test "員工不能發起、查詢、下載匯出" do
    export = create_export(scope: "filtered", kind: "expense")
    expense = create_expense(vendor: "全聯")
    create_reimbursement(employee: @employee)

    post "/api/data-exports", params: { scope: "single", kind: "expense", ids: [ expense.id ] },
                              headers: auth_headers(@employee), as: :json
    assert_response :forbidden
    post "/api/data-exports", params: { scope: "filtered", kind: "reimbursement" }, headers: auth_headers(@employee), as: :json
    assert_response :forbidden
    get "/api/data-exports/#{export.id}", headers: auth_headers(@employee)
    assert_response :forbidden
    get "/api/data-exports/#{export.id}/files/expense_csv", headers: auth_headers(@employee)
    assert_response :forbidden
  end

  # ---- 公司間隔離 ----

  test "別家公司的管理員查不到匯出、拿不到下載網址，也匯不出別家的紀錄" do
    expense = create_expense(vendor: "全聯")
    reimbursement = create_reimbursement(employee: @employee)
    export = generate_background_export

    get "/api/data-exports/#{export.id}", headers: auth_headers(@other_admin)
    assert_response :not_found
    get "/api/data-exports/#{export.id}/files/expense_csv", headers: auth_headers(@other_admin)
    assert_response :not_found

    { "expense" => expense, "reimbursement" => reimbursement }.each do |kind, record|
      post "/api/data-exports", params: { scope: "selected", kind: kind, ids: [ record.id ] },
                                headers: auth_headers(@other_admin), as: :json
      assert_response :unprocessable_content
      assert_equal "NO_RECORDS", response.parsed_body["error"]
    end
  end

  test "下載網址換成別家公司的管理員使用無效" do
    export = generate_background_export
    url = file_url(export, "expense_csv")

    # 同一個 token 綁的是 @admin；把 @admin 移到別家公司模擬「已非同公司管理員」
    @admin.update_columns(company_id: @other_company.id)
    get url
    assert_response :not_found
  end

  test "拿到下載網址後被降為員工，下載無效" do
    export = generate_background_export
    url = file_url(export, "expense_csv")

    @admin.update_columns(role: "employee")
    get url
    assert_response :not_found
  end

  test "範圍、類型、勾選筆數不正確時不受理" do
    create_expense(vendor: "全聯")
    reimbursements = Array.new(2) { create_reimbursement(employee: @employee) }

    { { scope: "full", kind: "expense" }                                    => "INVALID_SCOPE",
      { scope: "period", kind: "expense" }                                  => "INVALID_SCOPE",
      { scope: "filtered", kind: "all" }                                    => "INVALID_KIND",
      { scope: "single", kind: "reimbursement", ids: reimbursements.map(&:id) } => "IDS_REQUIRED" }.each do |params, code|
      post "/api/data-exports", params: params, headers: auth_headers(@admin), as: :json
      assert_response :unprocessable_content
      assert_equal code, response.parsed_body["error"], params.inspect
    end

    ids = Array.new(Api::DataExportsController::MAX_SELECTED + 1) { SecureRandom.uuid }
    post "/api/data-exports", params: { scope: "selected", kind: "expense", ids: ids }, headers: auth_headers(@admin), as: :json
    assert_equal "TOO_MANY_IDS", response.parsed_body["error"]
  end

  # ---- 垃圾桶排除、目前篩選 ----

  test "全部（目前篩選）不含垃圾桶內的紀錄，發生日期區間選填，沒有圖檔時當下回 CSV" do
    create_expense(vendor: "全聯", date: Date.new(2026, 11, 3))
    create_expense(vendor: "已刪除", date: Date.new(2026, 11, 4)).discard!
    create_expense(vendor: "區間外", date: Date.new(2026, 10, 31))

    post "/api/data-exports", params: filtered_params(date_from: "2026-11-01", date_to: "2026-11-30"),
                              headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_match "text/csv", response.media_type
    assert_equal [ "全聯" ], csv_rows(response.body).map { |r| r["賣方"] }

    post "/api/data-exports", params: filtered_params, headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ "全聯", "區間外" ], csv_rows(response.body).map { |r| r["賣方"] }
    assert_equal "支出 全部", DataExport.order(:created_at).last.scope_label
  end

  test "勾選的都在垃圾桶、或目前篩選沒有紀錄時不可匯出" do
    expense = create_expense(vendor: "全聯")
    expense.discard!

    post "/api/data-exports", params: { scope: "selected", kind: "expense", ids: [ expense.id ] },
                              headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "NO_RECORDS", response.parsed_body["error"]

    post "/api/data-exports", params: filtered_params, headers: auth_headers(@admin), as: :json
    assert_response :unprocessable_content
    assert_equal "NO_RECORDS", response.parsed_body["error"]
  end

  test "篩選條件寫法不對或不認得時回錯誤，不會擴大成匯出全部" do
    create_expense(vendor: "全聯")

    [ { payoutStatus: "paid" }, { collection_status: "collected" }, { category_ids: "abc" }, { page: 2 } ].each do |filters|
      assert_no_difference -> { DataExport.count } do
        post "/api/data-exports", params: filtered_params(**filters), headers: auth_headers(@admin), as: :json
      end
      assert_response :unprocessable_content
      assert_equal "INVALID_FILTER", response.parsed_body["error"], filters.inspect
    end

    post "/api/data-exports", params: { scope: "filtered", kind: "expense", filters: "paid" }, headers: auth_headers(@admin), as: :json
    assert_equal "INVALID_FILTER", response.parsed_body["error"]

    # 空的類別陣列、沒選的條件（null）照常受理
    post "/api/data-exports", params: filtered_params(category_ids: [], q: nil), headers: auth_headers(@admin), as: :json
    assert_response :ok
  end

  # ---- 代墊款 ----

  test "代墊款依全部紀錄的篩選匯出：排除草稿與別家公司，CSV 跳脫公式開頭的文字" do
    match = create_reimbursement(employee: @employee, status: "approved")
    match.update!(description: "=HYPERLINK(\"http://x\")", amount: 500)
    create_reimbursement(employee: @employee, status: "approved").update!(amount: 50)  # 金額不符
    create_reimbursement(employee: @employee, status: "in_review").update!(amount: 500) # 狀態不符
    create_reimbursement(employee: @employee, status: "draft").update!(amount: 500)
    create_reimbursement(employee: @other_employee, status: "approved").update!(amount: 500)

    post "/api/data-exports", params: { scope: "filtered", kind: "reimbursement", filters: { status: "approved", amount_min: "100" } },
                              headers: auth_headers(@admin), as: :json
    assert_response :ok
    rows = csv_rows(response.body)
    assert_equal DataExports::Csv::HEADERS["reimbursement"], rows.headers
    assert_equal [ "'=HYPERLINK(\"http://x\")" ], rows.map { |r| r["說明"] }
    assert_equal "代墊款 全部", DataExport.order(:created_at).last.scope_label

    # 沒有篩選：草稿以外的全部
    post "/api/data-exports", params: { scope: "filtered", kind: "reimbursement" }, headers: auth_headers(@admin), as: :json
    assert_equal 3, csv_rows(response.body).size
  end

  test "代墊款可以單筆匯出" do
    r = create_reimbursement(employee: @employee)
    r.update!(description: "計程車")

    post "/api/data-exports", params: { scope: "single", kind: "reimbursement", ids: [ r.id ] },
                              headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal [ "計程車" ], csv_rows(response.body).map { |row| row["說明"] }
    assert_equal "代墊款 單筆", DataExport.order(:created_at).last.scope_label
  end

  test "別家公司或草稿的代墊款單筆匯不出來" do
    [ create_reimbursement(employee: @other_employee), create_reimbursement(employee: @employee, status: "draft") ].each do |r|
      post "/api/data-exports", params: { scope: "single", kind: "reimbursement", ids: [ r.id ] },
                                headers: auth_headers(@admin), as: :json
      assert_response :unprocessable_content
      assert_equal "NO_RECORDS", response.parsed_body["error"]
    end
  end

  test "勾選的代墊款有圖檔時在背景產生，ZIP 檔名為發生日期_申請人_原始檔名" do
    @employee.update!(name: "陳小明")
    r = create_reimbursement(employee: @employee)
    r.update!(incurred_at: Date.new(2026, 11, 3))
    attach(r, "taxi.jpg")
    other = create_reimbursement(employee: @other_employee)

    post "/api/data-exports", params: { scope: "selected", kind: "reimbursement", ids: [ r.id, other.id ] },
                              headers: auth_headers(@admin), as: :json
    assert_response :accepted
    export = DataExport.find(response.parsed_body["id"])
    assert_equal "代墊款 勾選 2 筆", export.scope_label
    perform_enqueued_jobs

    export.reload
    assert_equal 1, export.record_count
    assert_equal %w[attachments_zip reimbursement_csv], export.files_blobs.map { |b| b.metadata["key"] }.sort
    rows = csv_rows(export.file_for("reimbursement_csv").download)
    assert_equal [ "2026-11-03_陳小明_taxi.jpg" ], rows.map { |row| row["圖檔"] }
    assert_equal [ "2026-11-03_陳小明_taxi.jpg" ], zip_names(export.file_for("attachments_zip"))
  end

  # ---- 背景產生 ----

  test "有圖檔時在背景產生：排除垃圾桶，圖檔放進 ZIP，寄信並寫站內通知" do
    kept = create_expense(vendor: "全聯", date: Date.new(2026, 11, 3))
    attach(kept, "receipt.jpg")
    attach(kept, "receipt.jpg")
    create_expense(vendor: "已刪除").discard!
    create_income(customer: "客戶甲")

    export = nil
    assert_emails(1) { export = generate_background_export }

    assert_equal "completed", export.status
    assert_equal 1, export.record_count
    assert_in_delta 7.days.from_now, export.expires_at, 1.minute
    assert_equal %w[attachments_zip expense_csv], export.files_blobs.map { |b| b.metadata["key"] }.sort

    expense_rows = csv_rows(export.file_for("expense_csv").download)
    assert_equal [ "全聯" ], expense_rows.map { |r| r["賣方"] }
    assert_equal "2026-11-03_全聯_receipt.jpg；2026-11-03_全聯_receipt(2).jpg", expense_rows.first["圖檔"]

    names = zip_names(export.file_for("attachments_zip"))
    assert_equal [ "2026-11-03_全聯_receipt(2).jpg", "2026-11-03_全聯_receipt.jpg" ], names.sort

    notification = Notification.find_by!(user: @admin, kind: "data_export_ready")
    assert_equal export.id, notification.payload["data_export_id"]
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "/admin/exports/#{export.id}"

    # 匯出檔不計入儲存空間：只算支出那兩張圖檔
    assert_equal kept.attachments.blobs.sum(:byte_size), AttachmentFiles.storage_bytes(@company)
  end

  # ---- 過期 ----

  test "過了失效時間拒絕取得下載網址與下載，排程刪檔但保留匯出紀錄" do
    export = generate_background_export
    url = file_url(export, "expense_csv")
    get url
    assert_response :ok

    export.update!(expires_at: 1.minute.ago)

    get "/api/data-exports/#{export.id}/files/expense_csv", headers: auth_headers(@admin)
    assert_response :gone
    assert_equal "EXPORT_EXPIRED", response.parsed_body["error"]
    get url
    assert_response :gone

    get "/api/data-exports/#{export.id}", headers: auth_headers(@admin)
    assert_equal true, response.parsed_body["expired"]
    assert_equal [], response.parsed_body["files"]

    CleanUpDataExportsJob.perform_now
    assert_not export.reload.files.attached?
    assert DataExport.exists?(export.id)
  end

  # ---- 背景產生的時間差與失敗 ----

  test "發起後、背景產生前移入垃圾桶的紀錄不匯出" do
    kept    = create_expense(vendor: "全聯")
    trashed = create_expense(vendor: "之後刪除")
    attach(kept, "receipt.jpg")

    post "/api/data-exports", params: { scope: "selected", kind: "expense", ids: [ kept.id, trashed.id ] },
                              headers: auth_headers(@admin), as: :json
    assert_response :accepted
    export = DataExport.find(response.parsed_body["id"])
    assert_equal 2, export.record_count

    trashed.discard!
    perform_enqueued_jobs

    assert_equal 1, export.reload.record_count
    assert_equal [ "全聯" ], csv_rows(export.file_for("expense_csv").download).map { |r| r["賣方"] }
  end

  test "背景產生失敗：標成失敗、不留檔案，寄失敗信並寫站內通知" do
    expense = create_expense(vendor: "全聯")
    attachment = attach(expense, "receipt.jpg")
    # 圖檔實體不見了，產生 ZIP 時讀檔失敗
    ActiveStorage::Blob.service.delete(attachment.blob.key)

    export = nil
    assert_emails(1) { export = generate_background_export(attach_record: false) }

    assert_equal "failed", export.status
    assert export.error.present?
    assert_not export.files.attached?
    assert Notification.exists?(user: @admin, kind: "data_export_failed")
    assert_equal "【Quickey】資料匯出失敗", ActionMailer::Base.deliveries.last.subject

    get "/api/data-exports/#{export.id}", headers: auth_headers(@admin)
    assert_equal "failed", response.parsed_body["status"]
    assert_nil response.parsed_body["error"]
  end

  test "發起超過 3 小時仍未完成的，排程檢查時標成失敗並通知；還沒逾時的不動" do
    stuck   = create_export(scope: "filtered", kind: "expense", status: "processing", created_at: 4.hours.ago)
    waiting = create_export(scope: "filtered", kind: "expense", status: "queued", created_at: 1.hour.ago)

    assert_emails(1) { CleanUpDataExportsJob.perform_now }

    assert_equal "failed", stuck.reload.status
    assert_equal "queued", waiting.reload.status
    assert Notification.exists?(user: @admin, kind: "data_export_failed", payload: { "data_export_id" => stuck.id, "scope_label" => "支出 全部" })

    # 逾時回收後，卡住的背景工作才跑完也不會改回完成
    assert_no_emails { GenerateDataExportJob.perform_now(stuck.id) }
    assert_equal "failed", stuck.reload.status
  end

  # ---- 稽核日誌 ----

  test "每次發起匯出寫一筆稽核日誌，記範圍、類型、條件（含當時的類別名稱）、筆數、是否含圖檔" do
    create_expense(vendor: "全聯", date: Date.new(2026, 11, 3))
    create_expense(vendor: "家樂福", date: Date.new(2026, 11, 5))
    category = @company.categories.of_kind("expense").first

    assert_difference -> { AuditLog.where(target_type: "data_export", action: "export").count }, 1 do
      post "/api/data-exports", params: filtered_params(date_from: "2026-11-01", date_to: "2026-11-30", q: "全", category_ids: [ category.id ]),
                                headers: auth_headers(@admin), as: :json
    end
    log = AuditLog.where(target_type: "data_export").sole
    export = DataExport.find(log.target_id)
    assert_equal @admin.id, log.actor_user_id
    filters = { "q" => "全", "category_ids" => [ category.id ], "category_names" => [ category.name ] }
    assert_equal({ "scope" => "filtered", "kind" => "expense", "record_count" => 1, "with_attachments" => false,
                   "criteria" => { "date_from" => "2026-11-01", "date_to" => "2026-11-30", "filters" => filters } },
                 log.after)

    get "/api/audit-logs", headers: auth_headers(@admin)
    assert_equal "支出 2026/11/01–2026/11/30", response.parsed_body["data"].first["target_label"]
    assert_equal "completed", export.status
  end

  private

  def create_expense(vendor:, date: Date.current, amount: 100)
    @company.expenses.create!(account: @account, source: "general", created_by: @admin,
      category: @company.categories.of_kind("expense").first, document_type: "receipt", tax_rate: "exempt_0",
      vendor: vendor, amount: amount, date: date)
  end

  def create_income(customer:, date: Date.current)
    @company.incomes.create!(account: @account, created_by: @admin, category: @company.categories.of_kind("income").first,
      document_type: "receipt", tax_rate: "exempt_0", customer: customer, amount: 100, date: date)
  end

  def attach(record, filename)
    blob = AttachmentFiles.create_blob!(io: StringIO.new("image-#{SecureRandom.hex(4)}"), filename: filename,
                                        content_type: "image/jpeg", user: @admin)
    ActiveStorage::Attachment.create!(record: record, name: AttachmentFiles::NAME, blob: blob)
  end

  def create_export(**attrs)
    @company.data_exports.create!(requested_by: @admin, criteria: {}, **attrs)
  end

  def filtered_params(**filters)
    { scope: "filtered", kind: "expense", filters: filters }
  end

  # 支出「全部」匯出並跑完背景產生。attach_record：沒有帶圖檔的支出時補一筆，確保走背景。
  def generate_background_export(attach_record: true)
    if attach_record && !ActiveStorage::Attachment.exists?(record_type: "Expense")
      attach(create_expense(vendor: "有圖檔"), "receipt.jpg")
    end
    perform_enqueued_jobs do
      post "/api/data-exports", params: filtered_params, headers: auth_headers(@admin), as: :json
    end
    assert_response :accepted
    DataExport.find(response.parsed_body["id"])
  end

  def file_url(export, key)
    get "/api/data-exports/#{export.id}/files/#{key}", headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body["url"]
  end

  def csv_rows(body)
    CSV.parse(body.dup.force_encoding("UTF-8").delete_prefix("﻿"), headers: true)
  end

  def zip_names(blob)
    Zip::File.open_buffer(blob.download).entries.map { |e| e.name.dup.force_encoding("UTF-8") }
  end
end
