# 稽核日誌列表「對象」的名稱（docs/資料模型.md §2.7）。一頁的日誌一次算完：每種對象
# 只查一次，每個查詢都限定本公司。
#
# 先查現有紀錄（含垃圾桶內的），所以改名後顯示現在的名稱；查不到代表已永久刪除，
# 改從該對象 purge 日誌的 before 取。預算沒有垃圾桶，刪除後從 delete 日誌的 before 取，
# 類別名稱仍換成現在的名稱。都查不到就沒有名稱，前端只顯示類型。
class AuditLogTargetLabels
  # 取名稱用到的快照 key，與各 model 的 audit_snapshot 相同。
  SNAPSHOT_KEYS = {
    "expense"            => %w[vendor date amount],
    "income"             => %w[customer date amount],
    "reimbursement"      => %w[employee_name incurred_at amount],
    "account"            => %w[name],
    "category"           => %w[name],
    "recurring_template" => %w[name],
    "transfer"           => %w[from_account_name to_account_name],
    "budget"             => %w[category_id category_name cycle period_start]
  }.freeze

  def initialize(company)
    @company = company
  end

  # 回 { [target_type, target_id] => 名稱 }；沒有名稱的不在結果內。
  def call(logs)
    pairs = logs.map { |log| [ log.target_type, log.target_id ] }.uniq

    pairs.group_by(&:first).each_with_object({}) do |(type, type_pairs), labels|
      ids = type_pairs.map(&:last)
      snapshots = current_snapshots(type, ids)
      removed   = removed_snapshots(type, ids - snapshots.keys)
      refresh_category_names!(removed) if type == "budget"
      snapshots = removed.merge(snapshots)

      snapshots.each do |id, snapshot|
        label = label_for(type, snapshot)
        labels[[ type, id ]] = label if label
      end
    end
  end

  private

  # 現有紀錄整理成和 purge 日誌 before 相同的形狀，後面只需要一套取名規則：
  # { 對象 id => { "vendor" => ..., "amount" => ... } }。
  def current_snapshots(type, ids)
    case type
    when "expense"
      rows(@company.expenses.where(id: ids), type)
    when "income"
      rows(@company.incomes.where(id: ids), type)
    when "reimbursement"
      # 只取需要的欄位：代墊款的憑證很大，不整列撈。
      rows(@company.reimbursements.where(id: ids).joins(:employee), type,
           select: [ "users.name", :incurred_at, :amount ])
    when "account"
      rows(@company.accounts.where(id: ids), type)
    when "category"
      rows(@company.categories.where(id: ids), type)
    when "recurring_template"
      rows(@company.recurring_templates.where(id: ids), type)
    when "budget"
      rows(@company.budgets.where(id: ids).joins(:category), type,
           select: [ :category_id, "categories.name", :cycle, :period_start ])
    when "transfer"
      @company.transfers.where(id: ids).includes(:from_account, :to_account).to_h do |transfer|
        [ transfer.id, { "from_account_name" => transfer.from_account&.name,
                         "to_account_name"   => transfer.to_account&.name } ]
      end
    when "data_export"
      # 資料匯出不會刪除，名稱為範圍文字（「支出 2026/11/01–2026/11/30」「完整匯出」）。
      @company.data_exports.where(id: ids).to_h { |export| [ export.id, { "name" => export.scope_label } ] }
    else
      {}
    end
  end

  def rows(scope, type, select: SNAPSHOT_KEYS.fetch(type))
    keys = SNAPSHOT_KEYS.fetch(type)
    scope.pluck(:id, *select).to_h { |id, *values| [ id, keys.zip(values).to_h ] }
  end

  # 已移除的對象：一般從 purge 日誌取，預算從 delete 日誌取。
  # 只取名稱用到的 key，不載入整份內容（支出可能含憑證）。值都是字串。
  def removed_snapshots(type, ids)
    keys = SNAPSHOT_KEYS[type]
    return {} if ids.empty? || keys.nil?

    action  = type == "budget" ? "delete" : "purge"
    columns = keys.map { |key| Arel.sql("audit_logs.before->>#{AuditLog.connection.quote(key)}") }
    @company.audit_logs.where(target_type: type, target_id: ids, action: action)
            .pluck(:target_id, *columns).to_h { |id, *values| [ id, keys.zip(values).to_h ] }
  end

  # 已刪除預算的類別名稱換成現在的名稱；類別已永久刪除時保留日誌內的名稱。
  def refresh_category_names!(snapshots)
    category_ids = snapshots.values.filter_map { |s| s["category_id"] }.uniq
    return if category_ids.empty?

    names = @company.categories.where(id: category_ids).pluck(:id, :name).to_h
    snapshots.each_value { |s| s["category_name"] = names[s["category_id"]] || s["category_name"] }
  end

  def label_for(type, snapshot)
    case type
    when "expense"       then snapshot["vendor"].presence || date_amount(snapshot["date"], snapshot["amount"])
    when "income"        then snapshot["customer"].presence || date_amount(snapshot["date"], snapshot["amount"])
    when "reimbursement" then snapshot["employee_name"].presence || date_amount(snapshot["incurred_at"], snapshot["amount"])
    when "transfer"      then transfer_label(snapshot)
    when "budget"        then budget_label(snapshot)
    else snapshot["name"].presence
    end
  end

  def transfer_label(snapshot)
    from, to = snapshot.values_at("from_account_name", "to_account_name")
    "#{from}→#{to}" if from.present? || to.present?
  end

  # 「交通費 2026/11 月預算」「交通費 2026 年預算」。
  def budget_label(snapshot)
    name  = snapshot["category_name"].presence
    start = snapshot["period_start"].presence&.to_date
    return name if start.nil?

    period = snapshot["cycle"] == "year" ? "#{start.year} 年預算" : "#{start.strftime('%Y/%m')} 月預算"
    [ name, period ].compact.join(" ")
  end

  # 格式同前端：2026/10/19 NT$ 12,340。
  def date_amount(date, amount)
    parts = []
    parts << date.to_date.strftime("%Y/%m/%d") if date.present?
    parts << "NT$ #{ActiveSupport::NumberHelper.number_to_delimited(amount.to_d.round)}" if amount.present?
    parts.join(" ").presence
  end
end
