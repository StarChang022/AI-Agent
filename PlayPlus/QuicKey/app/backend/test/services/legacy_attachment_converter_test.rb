require "test_helper"

# 既有 base64 圖檔一次性轉檔（docs/資料模型.md §2.4）：掛回原紀錄、檔名與順序不變、
# 代墊款與它產生的支出共用檔案、可重跑、解不開就中止，確認時比對實體檔案內容。
class LegacyAttachmentConverterTest < ActiveSupport::TestCase
  include TestDataHelpers

  setup do
    @company  = create_company
    @employee = create_user(company: @company)
    @admin    = create_user(company: @company, role: "admin")
    @reimbursement = create_reimbursement(employee: @employee)
    @converter = LegacyAttachmentConverter.new
  end

  def data_url(content, mime = "image/png")
    "data:#{mime};base64,#{Base64.strict_encode64(content)}"
  end

  def convert(type, id, items, share_with: nil, by: @employee)
    @converter.convert!(record_type: type, record_id: id, company_id: @company.id, uploaded_by_id: by.id,
                        items: items, share_with: share_with)
  end

  test "轉成實體檔案、掛回原紀錄，檔名與順序不變，確認通過" do
    items = [ { data_url: data_url("first"), filename: "收據1.png" }, { data_url: data_url("%PDF-1.4 x", "application/pdf"), filename: "發票.pdf" } ]
    assert_equal :converted, convert("Reimbursement", @reimbursement.id, items)

    blobs = AttachmentFiles.blobs_of(@reimbursement.reload)
    assert_equal [ "收據1.png", "發票.pdf" ], blobs.map { |b| b.filename.to_s }
    assert_equal [ "first", "%PDF-1.4 x" ], blobs.map(&:download)
    assert_equal [ @company.id ], blobs.map(&:company_id).uniq
    assert_equal [ @employee.id ], blobs.map(&:uploaded_by_id).uniq
    assert_nothing_raised { @converter.verify!(record_type: "Reimbursement", record_id: @reimbursement.id, items: items) }
  end

  test "沒有檔名時補 receipt-N" do
    convert("Reimbursement", @reimbursement.id, [ { data_url: data_url("a"), filename: nil } ])
    assert_equal "receipt-1", AttachmentFiles.blobs_of(@reimbursement.reload).sole.filename.to_s
  end

  test "代墊款產生的支出：同一張圖共用檔案，不同的圖各自建立" do
    convert("Reimbursement", @reimbursement.id, [ { data_url: data_url("same"), filename: "a.png" } ])
    expense_id = SecureRandom.uuid
    convert("Expense", expense_id, [ { data_url: data_url("same"), filename: "a.png" }, { data_url: data_url("new"), filename: "b.png" } ],
            share_with: [ "Reimbursement", @reimbursement.id ], by: @admin)

    shared = AttachmentFiles.blobs_of(@reimbursement.reload).sole
    expense_blobs = ActiveStorage::Attachment.where(record_type: "Expense", record_id: expense_id).order(:created_at).map(&:blob)
    assert_equal shared.id, expense_blobs.first.id
    assert_not_equal shared.id, expense_blobs.last.id
    assert_equal 2, ActiveStorage::Blob.where(company_id: @company.id).count
  end

  test "可重跑：已轉過的紀錄略過，不重複建立" do
    items = [ { data_url: data_url("a"), filename: "a.png" } ]
    convert("Reimbursement", @reimbursement.id, items)
    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_equal :skipped, convert("Reimbursement", @reimbursement.id, items)
    end
  end

  test "解不開的資料整筆中止，不留下一半的圖檔（含硬碟上的檔案）" do
    items = [ { data_url: data_url("ok"), filename: "a.png" }, { data_url: "not-a-data-url", filename: "b.png" } ]
    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_raises(LegacyAttachmentConverter::Invalid) { convert("Reimbursement", @reimbursement.id, items) }
    end
    assert_empty ActiveStorage::Attachment.where(record_id: @reimbursement.id)
  end

  test "確認：舊圖找不到、實體檔案不見都會中止；轉檔後多加的圖不影響" do
    items = [ { data_url: data_url("a"), filename: "a.png" } ]
    convert("Reimbursement", @reimbursement.id, items)
    blob = AttachmentFiles.blobs_of(@reimbursement.reload).sole

    @reimbursement.attachments.attach(
      AttachmentFiles.create_blob!(io: StringIO.new("new"), filename: "n.png", content_type: "image/png", user: @employee)
    )
    assert_nothing_raised { @converter.verify!(record_type: "Reimbursement", record_id: @reimbursement.id, items: items) }

    assert_raises(LegacyAttachmentConverter::Invalid) do
      @converter.verify!(record_type: "Reimbursement", record_id: @reimbursement.id, items: [ { data_url: data_url("b") } ])
    end
    blob.service.delete(blob.key)
    assert_raises(LegacyAttachmentConverter::Invalid) do
      @converter.verify!(record_type: "Reimbursement", record_id: @reimbursement.id, items: items)
    end
  end
end
