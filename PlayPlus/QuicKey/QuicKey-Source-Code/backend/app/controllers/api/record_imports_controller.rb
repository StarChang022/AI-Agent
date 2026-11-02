module Api
  # 支出／收入 Excel 匯入（docs/資料模型.md §5.4）。路由以 defaults 帶 kind
  # （expense / income），兩邊共用本 controller；僅超級管理員可用。
  # 解析與寫入邏輯在 app/services/excel_import/。
  class RecordImportsController < ApplicationController
    before_action :require_admin
    rescue_from ExcelImport::Error, with: :render_import_error

    # GET /api/expenses/import/template、/api/incomes/import/template
    def template
      send_data ExcelImport::TemplateBuilder.new(schema).to_xlsx,
        filename: "#{schema.label}匯入範本.xlsx",
        type: Mime[:xlsx].to_s,
        disposition: "attachment"
    end

    # POST /api/expenses/import/preview  FormData { file, column_mapping? }
    # 只解析不寫入。
    def preview
      result = ExcelImport::Parser.new(schema: schema, user: current_user)
        .parse(params[:file], column_mapping: json_param(:column_mapping))
      importable = result.importable

      render json: {
        total_rows: result.total_rows,
        counts: {
          importable: importable.size,
          warning:    importable.count { |r| r.status == "warning" },
          skipped:    result.records.size - importable.size
        },
        records: result.records.map { |r| serialize_record(r) },
        categories: result.categories.map { |c| { name: c.name, rows: c.rows, state: c.state, creatable: c.creatable } },
        accounts: result.accounts.map { |a| { name: a.name, rows: a.rows, state: a.state } }
      }
    end

    # POST /api/expenses/import  FormData { file, category_mapping, account_mapping?, excluded_rows?, column_mapping? }
    # 重新解析同一檔案後，在單一交易內建立全部可匯入、且使用者沒有移除的紀錄。
    def create
      outcome = ExcelImport::Importer.new(schema: schema, user: current_user).call(
        params[:file],
        category_mapping: json_param(:category_mapping),
        account_mapping:  json_param(:account_mapping),
        column_mapping:   json_param(:column_mapping),
        excluded_rows:    excluded_rows_param
      )

      render status: :created, json: {
        created_count:          outcome.created_count,
        excluded_count:         outcome.excluded_count,
        outside_cash_flow_count: outcome.outside_cash_flow_count,
        created_categories:     outcome.created_categories.map { |c| category_ref(c) },
        reactivated_categories: outcome.reactivated_categories.map { |c| category_ref(c) },
        skipped:  outcome.skipped.map  { |r| { rows: r.rows, messages: serialize_messages(r) } },
        warnings: outcome.warnings.map { |r| { rows: r.rows, messages: serialize_messages(r) } }
      }
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def schema
      @schema ||= ExcelImport::Schema.for(params[:kind])
    end

    # FormData 傳 JSON 字串；也接受一般 JSON body 的物件。
    def json_param(key)
      raw = params[key]
      return nil if raw.blank?
      return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      parsed = JSON.parse(raw.to_s)
      raise JSON::ParserError unless parsed.is_a?(Hash)
      parsed
    rescue JSON::ParserError
      code = { category_mapping: "INVALID_CATEGORY_MAPPING", account_mapping: "INVALID_ACCOUNT_MAPPING" }
        .fetch(key, "INVALID_COLUMN_MAPPING")
      raise ExcelImport::Error.new(code, "對應設定格式不正確，請重新預覽")
    end

    # excluded_rows：JSON 字串的正整數陣列（FormData），例 "[5,9]"；也接受一般陣列。最多 1,000 個。
    def excluded_rows_param
      raw = params[:excluded_rows]
      return [] if raw.blank?
      rows = raw.is_a?(String) ? JSON.parse(raw) : Array(raw)
      valid = rows.is_a?(Array) && rows.size <= ExcelImport::SheetReader::MAX_ROWS &&
        rows.all? { |r| r.is_a?(Integer) || r.to_s.match?(/\A\d+\z/) } && rows.all? { |r| r.to_i.positive? }
      raise JSON::ParserError unless valid
      rows.map(&:to_i)
    rescue JSON::ParserError
      raise ExcelImport::Error.new("INVALID_EXCLUDED_ROWS", "移除的資料有誤，請重新預覽")
    end

    def serialize_record(record)
      a = record.attrs
      {
        rows:   record.rows,
        status: record.status,
        summary: {
          date:          a[:date]&.iso8601,
          party:         a[:party],
          category_name: record.category_name,
          account_name:  (record.account&.name || record.account_name if record.importable?),
          outside_cash_flow: (record.outside_cash_flow if record.importable?),
          amount:        a[:amount]&.to_f,
          item_count:    record.items.size,
          document_type: a[:document_type],
          status:        a[:status]
        },
        messages: serialize_messages(record)
      }
    end

    def serialize_messages(record)
      record.messages.map { |m| { row: m.row, text: m.text } }
    end

    def category_ref(category)
      { id: category.id.to_s, name: category.name }
    end

    def render_import_error(error)
      render json: { error: error.code, message: error.message }, status: error.status
    end
  end
end
