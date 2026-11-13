module Api
  # 資料匯出（PRD 第 24 條、docs/資料模型.md §3.7、契約見 docs/dev/data-export-api.md）。
  # 全部限管理員；員工 403，別家公司的匯出 404。
  #
  # - create：一次匯出一個列表。沒有圖檔的當下回 CSV；有圖檔的排背景產生，回 202。每次都寫一筆稽核日誌。
  # - show：下載頁的資料。
  # - file：取某個檔案的短效下載網址。
  # - download：瀏覽器直接開的下載網址，不走 Bearer；token 綁使用者，下載時再檢查一次權限。
  class DataExportsController < ApplicationController
    MAX_SELECTED = 100

    # filtered 可帶的列表篩選（同 GET /api/expenses、收入列表畫面、代墊款「全部紀錄」頁），
    # 發生日期區間 date_from／date_to 另外處理。
    FILTER_KEYS = {
      "expense"       => %w[source category_ids payout_status q missing_invoice_no],
      "income"        => %w[recurring category_ids collection_status q missing_invoice_no],
      "reimbursement" => %w[status category_ids q amount_min amount_max]
    }.freeze
    BOOLEAN_FILTERS = %w[missing_invoice_no recurring].freeze
    AMOUNT_FILTERS  = %w[amount_min amount_max].freeze

    skip_before_action :authenticate!, only: :download
    before_action :require_admin, except: :download
    before_action :set_export, only: %i[show file]

    # POST /api/data-exports
    def create
      export = current_user.company.data_exports.new(requested_by: current_user)
      invalid = assign_request(export)
      return render_invalid(*invalid) if invalid

      selection = DataExports::Selection.new(export)
      export.record_count = selection.record_count
      if export.record_count.zero?
        return render_invalid("NO_RECORDS", "沒有可匯出的紀錄；垃圾桶內的紀錄請先還原再匯出")
      end
      export.with_attachments = selection.any_attachments?

      if export.background?
        export.status = "queued"
        save_with_audit!(export)
        GenerateDataExportJob.perform_later(export.id)
        render json: { id: export.id, status: export.status }, status: :accepted
      else
        export.status = "completed"
        export.completed_at = Time.current
        save_with_audit!(export)
        stream_csv(selection.section)
      end
    end

    # GET /api/data-exports/:id
    def show
      render json: serialize(@export)
    end

    # GET /api/data-exports/:id/files/:key
    def file
      return render_expired if @export.expired?

      blob = @export.status == "completed" ? @export.file_for(params[:key].to_s) : nil
      return render_not_found if blob.nil?

      token = verifier.generate([ @export.id.to_s, blob.id.to_s, current_user.id.to_s ],
                                expires_at: AttachmentFiles.url_expires_at)
      render json: { url: "/api/data-exports/download/#{token}" }
    end

    # GET /api/data-exports/download/:token
    def download
      export_id, blob_id, user_id = verifier.verified(params[:token].to_s)
      user   = User.find_by(id: user_id) if user_id
      export = DataExport.find_by(id: export_id) if export_id
      unless user&.status_active? && user.role_admin? && export && export.company_id == user.company_id
        return head :not_found
      end
      return render_expired if export.expired?

      blob = export.files_blobs.find_by(id: blob_id)
      return head :not_found if blob.nil?

      send_blob(blob)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "FORBIDDEN", message: "只有管理員可以匯出資料" }, status: :forbidden
    end

    def set_export
      @export = current_user.company.data_exports.find_by(id: params[:id])
      render_not_found if @export.nil?
    end

    # 填入範圍、類型、條件；有錯回 [代碼, 訊息]。
    def assign_request(export)
      scope = params[:scope].to_s
      return [ "INVALID_SCOPE", "匯出範圍不正確，請重新選擇" ] unless DataExport::SCOPES.include?(scope)

      kind = params[:kind].to_s
      return [ "INVALID_KIND", "匯出類型不正確，請重新選擇" ] unless DataExport::KINDS.include?(kind)

      export.scope = scope
      export.kind  = kind
      case scope
      when "single", "selected"
        ids = Array(params[:ids]).map { |id| id.to_s.strip }.compact_blank.uniq
        if ids.empty? || (scope == "single" && ids.size != 1)
          return [ "IDS_REQUIRED", "請選擇要匯出的紀錄" ]
        end
        return [ "TOO_MANY_IDS", "一次最多勾選 #{MAX_SELECTED} 筆匯出" ] if ids.size > MAX_SELECTED
        export.criteria = { "ids" => ids }
        nil
      else
        filtered_criteria(export, kind)
      end
    end

    # filtered：列表目前的分頁標籤與篩選，只留該列表有的條件；發生日期區間選填，沒帶就是不限日期。
    # 不認得的條件（拼錯、駝峰寫法、別的列表才有的、型別不對）回錯誤，不忽略：忽略會變成匯出比畫面更多的紀錄。
    def filtered_criteria(export, kind)
      given = params[:filters] || ActionController::Parameters.new
      return invalid_filter unless given.is_a?(ActionController::Parameters)

      scalars = [ "date_from", "date_to", *FILTER_KEYS[kind] ] - [ "category_ids" ]
      raw = given.slice(*scalars, :category_ids).permit(*scalars, category_ids: [])
      return invalid_filter if (given.keys - raw.keys).any?

      from = parse_date(raw[:date_from]) if raw[:date_from].present?
      to   = parse_date(raw[:date_to])   if raw[:date_to].present?
      if (raw[:date_from].present? && from.nil?) || (raw[:date_to].present? && to.nil?)
        return [ "INVALID_DATE", "日期格式不正確，請重新選擇" ]
      end
      return [ "INVALID_DATE", "起始日期不能晚於結束日期，請重新選擇" ] if from && to && from > to
      if AMOUNT_FILTERS.any? { |key| raw[key].present? && parse_amount(raw[key]).nil? }
        return [ "INVALID_AMOUNT", "金額格式不正確，請重新輸入" ]
      end

      filters = FILTER_KEYS[kind].each_with_object({}) do |key, h|
        value = raw[key]
        if BOOLEAN_FILTERS.include?(key)
          h[key] = true if ActiveModel::Type::Boolean.new.cast(value) == true
        elsif key == "category_ids"
          ids = Array(value).map(&:to_s).compact_blank
          next if ids.empty?

          # 稽核日誌要看得出匯出了哪些類別，類別之後改名或永久刪除也對得上，所以一併記當時的名稱
          # （順序同 ids；不是本公司的類別記 nil）。
          names = current_user.company.categories.where(id: ids).pluck(:id, :name).to_h { |id, name| [ id.to_s, name ] }
          h[key] = ids
          h["category_names"] = ids.map { |id| names[id] }
        elsif value.present?
          h[key] = value.to_s.strip
        end
      end
      export.criteria = { "date_from" => from&.iso8601, "date_to" => to&.iso8601, "filters" => filters }.compact
      nil
    end

    def invalid_filter
      [ "INVALID_FILTER", "篩選條件不正確，請重新整理頁面後再匯出" ]
    end

    def parse_date(raw)
      Date.iso8601(raw.to_s)
    rescue Date::Error
      nil
    end

    def parse_amount(raw)
      BigDecimal(raw.to_s.strip)
    rescue ArgumentError
      nil
    end

    def save_with_audit!(export)
      DataExport.transaction do
        export.save!
        AuditLog.record!(export, action: "export", after: export.audit_snapshot, by: current_user)
      end
    end

    def serialize(export)
      {
        id:               export.id,
        scope:            export.scope,
        kind:             export.kind,
        scope_label:      export.scope_label,
        record_count:     export.record_count,
        with_attachments: export.with_attachments,
        background:       export.background?,
        status:           export.status,
        created_at:       export.created_at.iso8601,
        completed_at:     export.completed_at&.iso8601,
        expires_at:       export.expires_at&.iso8601,
        expired:          export.expired?,
        requested_by:     { id: export.requested_by_id, name: export.requested_by&.name },
        files:            export.downloadable? ? files_json(export) : []
      }
    end

    def files_json(export)
      export.files_blobs.sort_by { |b| DataExport::FILE_KEYS.index(b.metadata["key"]) || 99 }.map do |blob|
        key = blob.metadata["key"]
        {
          key:       key,
          kind:      key == "attachments_zip" ? "zip" : "csv",
          filename:  blob.filename.to_s,
          byte_size: blob.byte_size
        }
      end
    end

    # 當下下載：紀錄分批讀、CSV 一行一行輸出給瀏覽器，不先組出整份，筆數多也不佔記憶體。
    # 不依筆數改走背景（規格：沒有圖檔就當下下載）。
    def stream_csv(section)
      rows = Enumerator.new do |y|
        section.each_record { |record| y << DataExports::Csv.row(section.type, record, []) }
      end
      filename = "#{DataExports::Generator::FILE_PREFIXES[section.type]}_#{Time.current.to_date.iso8601}.csv"

      response.headers["Content-Type"]        = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] =
        ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename)
      # 不讓中間層為了算 ETag 或反向代理緩衝而先收完整份
      response.headers["Cache-Control"]     = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"
      self.status = :ok
      self.response_body = DataExports::Csv.lines(DataExports::Csv::HEADERS[section.type], rows)
    end

    # 本機硬碟的檔案直接交給 Rack 串流，大 ZIP 不讀進記憶體；其他儲存服務退回整檔讀取。
    def send_blob(blob)
      options = { filename: blob.filename.to_s, type: blob.content_type, disposition: "attachment" }
      if blob.service.respond_to?(:path_for)
        send_file blob.service.path_for(blob.key), **options
      else
        send_data blob.download, **options
      end
    rescue ActionController::MissingFile, ActiveStorage::FileNotFoundError
      head :not_found
    end

    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("data_exports/download", 32),
        digest: "SHA256", serializer: JSON, url_safe: true
      )
    end

    def render_invalid(code, message)
      render json: { error: code, message: message }, status: :unprocessable_content
    end

    def render_not_found
      render json: { error: "NOT_FOUND", message: "找不到這筆匯出" }, status: :not_found
    end

    def render_expired
      render json: { error: "EXPORT_EXPIRED", message: "下載連結已失效，請重新匯出" }, status: :gone
    end
  end
end
