# 請款草稿可以先存一半（docs/資料模型.md §4.1）：類別、金額、發生日期在草稿時可空，
# 送出時才由 Reimbursement 的驗證擋。原本資料庫不允許空白，草稿缺這幾欄會存檔失敗（500）。
class AllowBlankDraftFieldsOnReimbursements < ActiveRecord::Migration[8.1]
  COLUMNS = %i[category_id amount incurred_at].freeze

  def up
    COLUMNS.each { |column| change_column_null :reimbursements, column, true }
  end

  # 還原前須先處理空值的草稿，否則會失敗。
  def down
    COLUMNS.each { |column| change_column_null :reimbursements, column, false }
  end
end
