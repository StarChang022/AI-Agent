# 確認既有圖檔都已轉成實體檔案且讀得到後，才移除舊的 base64 欄位（docs/資料模型.md §2.4）。
# 任何一筆不符就中止，舊欄位保留（錯誤訊息會指出是哪一筆）。每批只讀 10 筆，避免吃光記憶體。
# 移除後不可逆：回滾要同時還原部署前的資料庫與 storage volume 備份，加上舊版映像。
class RemoveLegacyAttachmentColumns < ActiveRecord::Migration[8.1]
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
    checked = 0

    LegacyReimbursement.where("cardinality(receipt_urls) > 0").find_each(batch_size: 10) do |r|
      items = r.receipt_urls.map { |url| { data_url: url } }
      converter.verify!(record_type: "Reimbursement", record_id: r.id, items: items)
      checked += 1
    end

    { "Expense" => LegacyExpense, "Income" => LegacyIncome, "Transfer" => LegacyTransfer }.each do |type, model|
      model.where("jsonb_array_length(attachments) > 0").find_each(batch_size: 10) do |rec|
        items = Array(rec.attachments).map { |a| { data_url: a["data_url"] } }
        converter.verify!(record_type: type, record_id: rec.id, items: items)
        checked += 1
      end
    end
    say "圖檔確認完成：#{checked} 筆紀錄的圖檔都讀得到且內容相同"

    remove_column :reimbursements, :receipt_urls,  :string, array: true, default: [], null: false
    remove_column :reimbursements, :receipt_names, :string, array: true, default: [], null: false
    remove_column :expenses,  :attachments, :jsonb, default: [], null: false
    remove_column :incomes,   :attachments, :jsonb, default: [], null: false
    remove_column :transfers, :attachments, :jsonb, default: [], null: false
  end

  # 只還原欄位，資料要從部署前的備份還原。
  def down
    add_column :reimbursements, :receipt_urls,  :string, array: true, default: [], null: false
    add_column :reimbursements, :receipt_names, :string, array: true, default: [], null: false
    add_column :expenses,  :attachments, :jsonb, default: [], null: false
    add_column :incomes,   :attachments, :jsonb, default: [], null: false
    add_column :transfers, :attachments, :jsonb, default: [], null: false
  end
end
