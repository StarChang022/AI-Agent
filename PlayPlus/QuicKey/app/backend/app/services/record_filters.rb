# 支出、收入、代墊款列表的篩選條件。列表（ExpensesController / IncomesController#index、
# ReimbursementsController#index / admin）與資料匯出的「全部（目前篩選）」（DataExports::Selection）
# 共用這一份，列表加條件時匯出跟著一致、筆數對得上。
# filters 可以是 controller 的 params，也可以是匯出存下的條件（字串 key 的 Hash）。
module RecordFilters
  module_function

  # 同 GET /api/expenses：來源、付款狀態，加共用條件；關鍵字比對賣方、說明、發票號碼。
  def expenses(scope, filters)
    scope = common(scope, filters, party_column: "vendor")
    scope = scope.where(payout_status: filters["payout_status"]) if filters["payout_status"].present?
    expense_source(scope, filters["source"].presence)
  end

  # 同收入列表：收款狀態、只看固定收入，加共用條件；關鍵字比對客戶、說明、發票號碼。
  def incomes(scope, filters)
    scope = common(scope, filters, party_column: "customer")
    scope = scope.where(collection_status: filters["collection_status"]) if filters["collection_status"].present?
    scope = scope.recurring if truthy?(filters["recurring"])
    scope
  end

  # 未填發票號碼、類別、發生日期區間（兩端含當日）、關鍵字。
  def common(scope, filters, party_column:)
    scope = scope.missing_invoice_no if truthy?(filters["missing_invoice_no"])
    scope = scope.where(category_id: Array(filters["category_ids"])) if filters["category_ids"].present?
    scope = scope.where("date >= ?", filters["date_from"]) if filters["date_from"].present?
    scope = scope.where("date <= ?", filters["date_to"])   if filters["date_to"].present?
    return scope if filters["q"].blank?

    kw = "%#{filters["q"].to_s.strip}%"
    scope.where("#{party_column} ILIKE :kw OR note ILIKE :kw OR invoice_no ILIKE :kw", kw: kw)
  end

  # 同代墊款「全部紀錄」列表（GET /api/reimbursements/admin）：狀態、申請人，加 reimbursement_common。
  def reimbursements(scope, filters)
    scope = scope.where(status: filters["status"])           if filters["status"].present?
    scope = scope.where(employee_id: filters["employee_id"]) if filters["employee_id"].present?
    reimbursement_common(scope, filters)
  end

  # 代墊款前台、後台列表共用：關鍵字（賣方、說明、發票號碼）、類別、發生日期區間、金額區間（兩端含）。
  def reimbursement_common(scope, filters)
    if filters["q"].present?
      kw = "%#{filters["q"].to_s.strip}%"
      scope = scope.where("vendor ILIKE :kw OR description ILIKE :kw OR invoice_no ILIKE :kw", kw: kw)
    end
    scope = scope.where(category_id: Array(filters["category_ids"])) if filters["category_ids"].present?
    scope = scope.where("incurred_at >= ?", filters["date_from"])   if filters["date_from"].present?
    scope = scope.where("incurred_at <= ?", filters["date_to"])     if filters["date_to"].present?
    scope = scope.where("amount >= ?", filters["amount_min"])       if filters["amount_min"].present?
    scope = scope.where("amount <= ?", filters["amount_max"])       if filters["amount_max"].present?
    scope
  end

  # 固定紀錄的 source 仍是 general，所以 recurring、general 都看 recurring_period。
  def expense_source(scope, source)
    case source
    when nil         then scope
    when "recurring" then scope.recurring
    when "general"   then scope.general.non_recurring
    else scope.where(source: source)
    end
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end
end
