# 固定收支產生的紀錄指回範本（docs/資料模型.md §2.2、§2.6）。範本永久刪除時
# recurring_template_id 清空、recurring_period 保留，「固定」標示以 recurring_period 判斷。
# 同一範本的同一期只能有一筆，垃圾桶內的紀錄也算，排程重跑才不會重複。
class AddRecurringToExpensesAndIncomes < ActiveRecord::Migration[8.1]
  def change
    %i[expenses incomes].each do |table|
      add_reference table, :recurring_template, type: :uuid, foreign_key: true, index: false
      add_column table, :recurring_period, :string
      add_index table, [ :recurring_template_id, :recurring_period ], unique: true,
        where: "recurring_template_id IS NOT NULL",
        name: "index_#{table}_on_recurring_template_and_period"
    end
  end
end
