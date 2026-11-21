# 既有 base64 圖檔轉成實體檔案、掛回原紀錄（docs/資料模型.md §2.4「既有資料轉檔」）。
# 舊欄位先保留，下一支 migration 逐一確認讀得到後才移除。部署前先備份資料庫與 storage volume。
#
# - 每筆紀錄各自一個交易，中途失敗可重跑（已轉好的紀錄會略過）。
# - 每批只讀 10 筆：每筆都帶 base64 圖檔，一次讀太多會吃光記憶體。
# - 先轉代墊款，再轉支出：代墊款核准產生的支出若是同一張圖，共用代墊款的檔案。
# - 只讀資料表，不經 app 的 model（model 已改成實體檔案）。
class ConvertLegacyAttachmentsToFiles < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class LegacyReimbursement < ActiveRecord::Base
    self.table_name = "reimbursements"
  end

  class LegacyExpense < ActiveRecord::Base
    self.table_name = "expenses"
  end

  class LegacyIncome < ActiveRecord::Base
    self.table_name = "incomes"
  end

  class LegacyTransfer < ActiveRecord::Base
    self.table_name = "transfers"
  end

  def up
    converter = LegacyAttachmentConverter.new
    counts = Hash.new(0)

    LegacyReimbursement.where("cardinality(receipt_urls) > 0").find_each(batch_size: 10) do |r|
      items = r.receipt_urls.each_with_index.map { |url, i| { data_url: url, filename: r.receipt_names[i] } }
      counts[converter.convert!(record_type: "Reimbursement", record_id: r.id, company_id: r.company_id,
                                uploaded_by_id: r.employee_id, items: items)] += 1
    end

    LegacyExpense.where("jsonb_array_length(attachments) > 0").find_each(batch_size: 10) do |e|
      share = e.source_ref_id ? [ "Reimbursement", e.source_ref_id ] : nil
      counts[converter.convert!(record_type: "Expense", record_id: e.id, company_id: e.company_id,
                                uploaded_by_id: e.created_by_id, items: jsonb_items(e.attachments), share_with: share)] += 1
    end

    { "Income" => LegacyIncome, "Transfer" => LegacyTransfer }.each do |type, model|
      model.where("jsonb_array_length(attachments) > 0").find_each(batch_size: 10) do |rec|
        counts[converter.convert!(record_type: type, record_id: rec.id, company_id: rec.company_id,
                                  uploaded_by_id: rec.created_by_id, items: jsonb_items(rec.attachments))] += 1
      end
    end

    say "圖檔轉檔：轉換 #{counts[:converted]} 筆紀錄，略過（已轉過）#{counts[:skipped]} 筆"
  end

  # 轉好的檔案不刪（可能已有新上傳的圖檔混在一起）；舊欄位還在，重跑 up 會略過已轉的紀錄。
  def down; end

  private

  def jsonb_items(attachments)
    Array(attachments).map { |a| { data_url: a["data_url"], filename: a["filename"] } }
  end
end
