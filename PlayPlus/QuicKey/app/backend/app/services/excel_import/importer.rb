module ExcelImport
  # 解析第 5 段「產生紀錄」：重新解析檔案後，依使用者的類別對應在單一交易內建立
  # 全部可匯入的紀錄；任一筆失敗整批回滾。每筆照一般新增寫稽核日誌，after 加上
  # via: "excel_import" 標示建立方式。匯入時新增類別記 create、重新啟用類別記 update，
  # 同樣標示來源，操作人為匯入者。
  #
  # category_mapping：{ 類別名稱 => 既有類別 id | "create" | "reactivate" }，
  # 「（未填類別）」的名稱為 ""。沒帶的名稱走預設：找不到 → create、停用中 → reactivate；
  # 未填類別沒有預設，一定要對應到既有類別。
  #
  # account_mapping：{ 帳戶名稱 => 既有帳戶 id }。檔內找不到的帳戶名稱都要對應，沒有預設。
  class Importer
    Outcome = Data.define(:created_count, :excluded_count, :outside_cash_flow_count, :created_categories,
                          :reactivated_categories, :skipped, :warnings)

    def initialize(schema:, user:)
      @schema  = schema
      @user    = user
      @company = user.company
    end

    # excluded_rows：使用者在預覽移除的單據（第一列 Excel 列號）；不建立，也不處理
    # 只被它們用到的類別。有列號對不上可匯入單據的第一列（例：預覽後換了檔案）→ 整次不匯入。
    def call(upload, category_mapping: nil, account_mapping: nil, column_mapping: nil, excluded_rows: [])
      result = Parser.new(schema: @schema, user: @user).parse(upload, column_mapping: column_mapping)
      excluded = excluded_rows.to_set
      unless excluded.subset?(result.importable.to_set { |r| r.rows.first })
        raise Error.new("INVALID_EXCLUDED_ROWS", "檔案內容與預覽不同，請重新預覽")
      end
      records = result.importable.reject { |r| excluded.include?(r.rows.first) }
      raise Error.new("NOTHING_TO_IMPORT", "沒有可匯入的資料") if records.empty?

      used_categories = result.categories.reject { |c| (c.rows - excluded.to_a).empty? }
      plan = plan_categories(used_categories, normalize_mapping(category_mapping))
      used_accounts = result.accounts.reject { |a| (a.rows - excluded.to_a).empty? }
      accounts = plan_accounts(used_accounts, normalize_mapping(account_mapping))
      # 應付日期照手動新增：以匯入當天為登錄日依公司目前的付款日計算，整批同一個自動值
      @today = Date.current
      created     = []
      reactivated = []
      outside_cash_flow = 0

      ActiveRecord::Base.transaction do
        resolved = plan.to_h do |key, (action, target)|
          category =
            case action
            when :create
              create_category!(target).tap { |c| created << c }
            when :reactivate
              reactivate_category!(target).tap { |c| reactivated << c }
            else
              target
            end
          [ key, category ]
        end

        records.each do |record|
          category = record.category || resolved.fetch(record.category_name.to_s.downcase)
          account  = record.account || accounts.fetch(record.account_name.downcase)
          create_record!(record, category: category, account: account)
          settled_at = record.attrs[:settled_at]
          outside_cash_flow += 1 if settled_at && settled_at < account.opening_month
        end
      end

      Outcome.new(
        created_count: records.size,
        excluded_count: result.importable.size - records.size,
        outside_cash_flow_count: outside_cash_flow,
        created_categories: created,
        reactivated_categories: reactivated,
        skipped: result.records.reject(&:importable?),
        warnings: records.select { |r| r.status == "warning" }
      )
    end

    private

    def normalize_mapping(mapping)
      (mapping || {}).to_h.to_h { |name, value| [ name.to_s.strip.downcase, value.to_s ] }
    end

    # 檢查對應是否合法並決定動作。對應到的既有類別已停用或不存在 → 409，請前端重新預覽。
    def plan_categories(entries, mapping)
      active = @company.categories.of_kind(@schema.kind).active

      entries.to_h do |entry|
        value = mapping[entry.key].presence || default_action(entry)
        action =
          case value
          when "create"
            invalid_mapping!(entry) unless entry.creatable
            [ :create, entry.name ]
          when "reactivate"
            invalid_mapping!(entry) unless entry.state == "archived"
            [ :reactivate, entry.archived_category ]
          else
            category = active.find_by(id: value) if value.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
            raise Error.new("CATEGORY_CHANGED", "類別已變更，請重新預覽", status: :conflict) if category.nil?
            [ :existing, category ]
          end
        [ entry.key, action ]
      end
    end

    # 帳戶只能對應到既有帳戶。對應到的帳戶已刪除或不存在 → 409，請前端重新預覽。
    def plan_accounts(entries, mapping)
      entries.to_h do |entry|
        value = mapping[entry.key]
        if value.blank?
          raise Error.new("INVALID_ACCOUNT_MAPPING", "請選擇帳戶「#{entry.name.truncate(20)}」要對應到哪個帳戶")
        end
        account = @company.accounts.kept.find_by(id: value)
        raise Error.new("ACCOUNT_CHANGED", "帳戶已變更，請重新預覽", status: :conflict) if account.nil?
        [ entry.key, account ]
      end
    end

    # 找不到（可新增）→ create、停用中 → reactivate；未填類別與名稱過長的沒有預設。
    def default_action(entry)
      return "create" if entry.creatable
      return "reactivate" if entry.state == "archived"
      raise Error.new("INVALID_CATEGORY_MAPPING", "請選擇類別#{category_label(entry)}要對應到哪個既有類別")
    end

    def invalid_mapping!(entry)
      raise Error.new("INVALID_CATEGORY_MAPPING", "類別#{category_label(entry)}的對應方式不正確，請重新選擇")
    end

    def category_label(entry)
      entry.state == "blank" ? "（未填類別）" : "「#{entry.name.truncate(20)}」"
    end

    def create_category!(name)
      sort_order = (@company.categories.of_kind(@schema.kind).maximum(:sort_order) || -1) + 1
      category = @company.categories.create!(kind: @schema.kind, name: name, account_code: "", sort_order: sort_order)
      AuditLog.record!(category, action: "create", by: @user, after: category.audit_snapshot.merge(via: "excel_import"))
      category
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[ExcelImport] category create failed: #{e.record.errors.full_messages.inspect}")
      raise Error.new("IMPORT_FAILED", "無法新增類別「#{name.truncate(20)}」，整批未匯入，請改名或對應到既有類別")
    end

    def reactivate_category!(category)
      category.update!(is_archived: false)
      AuditLog.record!(category, action: "update", by: @user,
        before: { is_archived: true }, after: { is_archived: false, via: "excel_import" })
      category
    end

    def create_record!(record, category:, account:)
      record_model = @schema.kind == "expense" ? build_expense(record) : build_income(record)
      record_model.category = category
      record_model.account  = account
      record_model.save!
      AuditLog.record!(record_model, action: "create", by: @user,
        after: record_model.audit_snapshot.merge(via: "excel_import"))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      # 解析後帳戶才被刪除：和對應到已刪除帳戶一樣，請使用者重新預覽。
      if e.respond_to?(:record) && e.record.errors.of_kind?(:account_id, :deleted)
        raise Error.new("ACCOUNT_CHANGED", "帳戶已變更，請重新預覽", status: :conflict)
      end

      detail = e.respond_to?(:record) ? e.record.errors.full_messages.inspect : "#{e.class}: #{e.message}"
      Rails.logger.warn("[ExcelImport] row #{record.rows.first} save failed: #{detail}")
      raise Error.new("IMPORT_FAILED", "第 #{record.rows.first} 列無法建立，整批未匯入，請檢查這列的資料")
    end

    def common_attrs(record)
      a = record.attrs
      {
        created_by: @user, document_type: a[:document_type], tax_id: a[:tax_id], invoice_no: a[:invoice_no],
        tax_rate: a[:tax_rate], pre_tax_amt: a[:pre_tax_amt], tax_amt: a[:tax_amt], amount: a[:amount],
        date: a[:date], invoice_date: a[:invoice_date], note: a[:note],
        items: record.items.map { |i| item_json(i) }
      }
    end

    # 付款狀態與應付日期照手動新增（ExpensesController#create）的規則：有填應付日期且與
    # 自動值不同時視為手動修改。
    def build_expense(record)
      expense = @company.expenses.new(common_attrs(record).merge(source: "general", vendor: record.attrs[:party]))
      expense.snapshot_planned_payout!(@today)
      expense.assign_planned_payout_date(record.attrs[:planned_date]) if record.attrs[:planned_date]
      if record.attrs[:status] == "paid"
        expense.payout_status = "paid"
        expense.paid_at       = record.attrs[:settled_at]
        expense.paid_by       = @user
      else
        expense.payout_status = "pending"
      end
      expense
    end

    # 應收日期空白時為發生日期（由 Income 處理）。
    def build_income(record)
      income = @company.incomes.new(common_attrs(record).merge(
        customer:          record.attrs[:party],
        collection_status: record.attrs[:status],
        collected_at:      record.attrs[:status] == "collected" ? record.attrs[:settled_at] : nil
      ))
      income.assign_planned_collection_date(record.attrs[:planned_date]) if record.attrs[:planned_date]
      income
    end

    # 品項存法同手動新增（jsonb：name / quantity / unit_price / subtotal）。
    def item_json(item)
      {
        "name"       => item[:name],
        "quantity"   => json_number(item[:quantity]),
        "unit_price" => json_number(item[:unit_price]),
        "subtotal"   => json_number(item[:subtotal])
      }
    end

    def json_number(value)
      value.frac.zero? ? value.to_i : value.to_f
    end
  end
end
