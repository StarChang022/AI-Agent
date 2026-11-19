module Api
  # 收入 CRUD endpoints。全部要求 JWT + role=admin（後台功能），並限定於
  # 呼叫者所屬 company。鏡像 ExpensesController，差異：
  # - customer（必填）取代 vendor；無 source / source_ref_id（代墊款不轉成收入）
  # - 收款相關為 collection_status / collected_at（對應 payout_status / paid_at）
  # - 應收日期 planned_collection_date 預設為發生日期，不看公司付款日、沒有改回自動排程
  # - 無 paid_by 類人員欄位（§2.6 未定義 received_by）
  class IncomesController < ApplicationController
    include AccountParam
    include RecordAttachments

    # update 寫入 AuditLog 時只對這些欄位做 diff（jsonb 以外的 noise 不入 log）。
    # collected_at 由 update 走 partial path 時可能被改——算一般欄位更新。
    AUDITED_UPDATE_FIELDS = %w[
      document_type customer tax_id invoice_no tax_rate
      pre_tax_amt tax_amt amount date invoice_date note items
      category_id account_id collected_at planned_collection_date
    ].freeze

    before_action :require_admin
    before_action :require_company_account, only: :create
    before_action :set_any_income, only: :show
    before_action :set_income, only: %i[update destroy collect revert_collect]
    before_action :set_discarded_income, only: %i[restore purge]
    before_action :set_editable_income, only: :destroy_attachment

    # GET /api/incomes/pending-batches
    # 待收款依應收日期分組，格式同 /api/expenses/pending-batches（沒有 source_meta）：
    # { groups: [{ key, date, overdue, total, count, rows }] }。逾期合成一組排最前面。
    def pending_batches
      scope = current_user.company.incomes.kept.uncollected
        .includes(:category, :account, :created_by)
        .order(:planned_collection_date, created_at: :desc)

      groups = PendingBatches.group(scope.to_a, date_of: :planned_collection_date.to_proc) do |rows|
        { rows: rows.map { |i| list_serialize(i) } }
      end
      render json: { groups: groups }
    end

    # GET /api/incomes?discarded=&recurring=&missing_invoice_no=&category_ids[]=&collection_status=&date_from=&date_to=&q=
    # 預設只回未刪；discarded=true → 回垃圾桶。recurring=true → 只看固定收入。
    # missing_invoice_no=true → 只看文件類型為發票、發票號碼空白的紀錄。
    # 垃圾桶預設依 deleted_at 新到舊；正常列表依開立日新到舊。
    # q 對 customer / note / invoice_no 三欄 OR ILIKE。
    def index
      discarded = discarded_only?
      scope = current_user.company.incomes
      scope = discarded ? scope.discarded : scope.kept
      # 列表目前回全欄位（含圖檔），先把圖檔一起載入
      scope = scope.includes(:category, :account, :created_by).with_attached_attachments
      # 篩選與期間匯出共用（RecordFilters）
      scope = RecordFilters.incomes(scope, params)

      scope = discarded ? scope.order(deleted_at: :desc) : scope.order(date: :desc, created_at: :desc)
      render json: scope.map { |i| serialize(i) }
    end

    # GET /api/incomes/:id
    # 垃圾桶內的也查得到（回傳 deleted_at、deleted_by），比照支出與移轉。
    def show
      deleted_by = AuditLog.deleted_by_map(current_user.company, "income", [ @income.id ])[@income.id] if @income.discarded?
      render json: serialize(@income, deleted_by: deleted_by)
    end

    # POST /api/incomes
    # collection_status='collected' → 立即寫入 collection_status + collected_at
    # （client 可帶 collected_at 覆寫，否則為今天）。
    # 未帶或 'uncollected' → 建立為待收款。狀態之後要切換走 /collect / /revert-collect。
    def create
      category = current_user.company.categories.selectable.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
      return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "income"

      account = find_account_param
      return if performed?

      initial_status = params[:collection_status].presence || "uncollected"
      return render_error("INVALID_COLLECTION_STATUS", :unprocessable_content) unless Income::COLLECTION_STATUSES.include?(initial_status)

      income = current_user.company.incomes.new(created_by: current_user, category: category, account: account)
      assign_fields(income)
      assign_planned_collection(income)
      return if performed?
      blobs = claim_attachments(income)
      if initial_status == "collected"
        income.collection_status = "collected"
        income.collected_at      = parse_collected_at || Date.current
      else
        income.collection_status = "uncollected"
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = income.save
        if saved
          attach_claimed!(income, blobs)
          AuditLog.record!(income, action: "create", by: current_user, after: income.audit_snapshot)
        end
      end

      if saved
        render json: serialize(income), status: :created
      else
        render json: validation_error(income), status: :unprocessable_content
      end
    end

    # PATCH /api/incomes/:id
    # partial：只覆寫 client 傳來的欄位。collection_status 本身仍走 collect / revert_collect；
    # 但若已為 collected，可透過本 endpoint 修改 collected_at（例如更正收款日）。
    def update
      if params.key?(:category_id)
        category = current_user.company.categories.selectable(@income.category_id).find_by(id: params[:category_id])
        return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
        return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "income"
        @income.category = category
      end

      if params.key?(:account_id)
        account = find_account_param
        return if performed?
        @income.account = account
      end

      assign_fields(@income)
      assign_planned_collection(@income)
      return if performed?
      blobs = claim_attachments(@income)

      if params.key?(:collected_at) && @income.collection_status == "collected"
        new_collected_at = parse_collected_at
        return render_error("COLLECTED_AT_REQUIRED", :unprocessable_content) if new_collected_at.nil?
        @income.collected_at = new_collected_at
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = @income.save
        if saved
          attachments_change = attach_claimed!(@income, blobs)
          audit_update_with_attachments!(@income, AUDITED_UPDATE_FIELDS, attachments_change)
        end
      end

      if saved
        render json: serialize(@income)
      else
        render json: validation_error(@income), status: :unprocessable_content
      end
    end

    # DELETE /api/incomes/:id
    # 軟刪，進垃圾桶（寫入 deleted_at）。已收款（collected）→ 擋，需先切回 uncollected 再刪
    # （對齊規格「待收款、待付款才能刪除」）。
    def destroy
      return render_error("COLLECTED_NOT_DELETABLE", :conflict) if @income.collection_status == "collected"

      ActiveRecord::Base.transaction do
        @income.discard!
        AuditLog.record!(@income, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @income.deleted_at&.iso8601 })
      end

      render json: {}, status: :ok
    end

    # PATCH /api/incomes/:id/restore
    # 從垃圾桶還原：清掉 deleted_at，狀態保留。
    # 規則在 IncomeTrash，批次還原共用。
    def restore
      IncomeTrash.restore!(@income, by: current_user)
      render json: serialize(@income)
    end

    # DELETE /api/incomes/:id/purge
    # 永久刪除：真的 DELETE。前端須已做二次確認。規則在 IncomeTrash，批次永久刪除共用。
    def purge
      IncomeTrash.purge!(@income, by: current_user)
      render json: {}, status: :ok
    end

    # POST /api/incomes/batch_restore   body: { ids: [...] }
    # 每筆各自依單筆規則處理，一筆失敗不影響其他筆（docs/dev/trash-batch-api.md）。
    def batch_restore
      ids = TrashActions.parse_ids(params[:ids])
      result = TrashActions.run_batch(trash_scope, ids) { |i| IncomeTrash.restore!(i, by: current_user) }
      render json: result
    end

    # POST /api/incomes/batch_purge   body: { ids: [...] }
    def batch_purge
      ids = TrashActions.parse_ids(params[:ids])
      result = TrashActions.run_batch(trash_scope, ids) { |i| IncomeTrash.purge!(i, by: current_user) }
      render json: result
    end

    # PATCH /api/incomes/:id/collect
    # 標記為已收款：collected_at（client 帶確認視窗的日期、沒帶為今天）。
    def collect
      collected_on = parse_collected_at || Date.current

      ActiveRecord::Base.transaction do
        prev_collected_at = @income.collected_at&.iso8601
        @income.update!(collection_status: "collected", collected_at: collected_on)
        AuditLog.record!(@income, action: "status_change", by: current_user,
          before: { collection_status: "uncollected", collected_at: prev_collected_at },
          after:  { collection_status: "collected",   collected_at: collected_on.iso8601 })
      end

      render json: serialize(@income)
    end

    # PATCH /api/incomes/:id/revert-collect
    # 取消收款：改為 uncollected，**保留** collected_at（規格要求資料不清空、
    # 僅由前端依 collection_status 決定是否顯示；再度切回 collected 時可沿用）。
    def revert_collect
      ActiveRecord::Base.transaction do
        preserved_collected_at = @income.collected_at&.iso8601
        @income.update!(collection_status: "uncollected")
        AuditLog.record!(@income, action: "status_change", by: current_user,
          before: { collection_status: "collected",   collected_at: preserved_collected_at },
          after:  { collection_status: "uncollected", collected_at: preserved_collected_at })
      end
      render json: serialize(@income)
    end

    # DELETE /api/incomes/:id/attachments/:attachment_id
    # 編輯頁刪除已存圖檔，立即永久刪除（docs/dev/attachments-api.md 第 4 節）。
    def destroy_attachment
      remove_attachment!(@income)
      render json: serialize(@income)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_income
      @income = current_user.company.incomes.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @income.nil?
    end

    def set_any_income
      @income = current_user.company.incomes.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @income.nil?
    end

    # 刪圖檔：垃圾桶內的紀錄不能編輯。
    def set_editable_income
      @income = current_user.company.incomes.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if @income.nil?
      render_in_trash if @income.discarded?
    end

    # restore / purge 走垃圾桶，找 discarded 的那筆。
    def set_discarded_income
      @income = current_user.company.incomes.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @income.nil?
    end

    # 批次用：本公司垃圾桶內的收入。
    def trash_scope
      current_user.company.incomes.discarded
    end

    # 填入可編輯欄位；只處理 client 有帶的 key（create 會全帶、update 為 partial）。
    # 不含 created_by / company / collection_status（各有專屬處理）。
    def assign_fields(i)
      i.document_type = params[:document_type]              if params.key?(:document_type)
      i.customer      = params[:customer]                   if params.key?(:customer)
      i.tax_id        = params[:tax_id].presence            if params.key?(:tax_id)
      i.invoice_no    = params[:invoice_no].presence        if params.key?(:invoice_no)
      i.tax_rate      = params[:tax_rate]                   if params.key?(:tax_rate)
      i.pre_tax_amt   = parse_amount(params[:pre_tax_amt])  if params.key?(:pre_tax_amt)
      i.tax_amt       = parse_amount(params[:tax_amt])      if params.key?(:tax_amt)
      i.amount        = parse_amount(params[:amount])       if params.key?(:amount)
      i.date          = params[:date]                       if params.key?(:date)
      i.invoice_date  = params[:invoice_date].presence      if params.key?(:invoice_date)
      i.note          = params[:note].presence              if params.key?(:note)
      i.items         = json_array(params[:items])          if params.key?(:items)
    end

    # 應收日期參數：有帶就照存；null 或空字串視為沒帶（預設為發生日期）。
    def assign_planned_collection(i)
      raw = params[:planned_collection_date]
      return if raw.blank?
      value = parse_date(raw)
      return render_error("INVALID_DATE", :unprocessable_content) if value.nil?
      i.assign_planned_collection_date(value)
    end

    def parse_date(raw)
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def discarded_only?
      ActiveModel::Type::Boolean.new.cast(params[:discarded]) == true
    end

    # collected_at 參數解析：接受 'yyyy-mm-dd' 字串；格式錯誤或空字串回 nil。
    def parse_collected_at
      raw = params[:collected_at]
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_amount(raw)
      return nil if raw.nil? || raw == ""
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def json_array(raw)
      return [] if raw.blank?
      Array(raw).map { |el| el.respond_to?(:to_unsafe_h) ? el.to_unsafe_h : el }
    end

    # 單筆回全欄位（含圖檔、品項）。
    # deleted_by：垃圾桶的操作人（最新一筆刪除稽核的操作者），只有單筆查詢會查；其餘為 nil。
    def serialize(i, deleted_by: nil)
      summary_fields(i).merge(deleted_by: person_ref(deleted_by), attachments: AttachmentFiles.as_json(i, current_user))
    end

    # 列表精簡格式：不帶圖檔與品項（目前 pending-batches 用）。
    def list_serialize(i)
      summary_fields(i).except(:items)
    end

    def summary_fields(i)
      {
        id:                i.id.to_s,
        recurring_template_id: i.recurring_template_id&.to_s,
        recurring_period:  i.recurring_period,
        document_type:     i.document_type,
        customer:          i.customer,
        tax_id:            i.tax_id,
        invoice_no:        i.invoice_no,
        tax_rate:          i.tax_rate,
        pre_tax_amt:       i.pre_tax_amt&.to_f,
        tax_amt:           i.tax_amt&.to_f,
        amount:            i.amount.to_f,
        category:          category_ref(i.category),
        account:           account_ref(i.account),
        date:              i.date.iso8601,
        invoice_date:      i.invoice_date&.iso8601,
        planned_collection_date: i.planned_collection_date.iso8601,
        note:              i.note,
        items:             i.items,
        collection_status: i.collection_status,
        collected_at:      i.collected_at&.iso8601,
        created_by:        person_ref(i.created_by),
        deleted_at:        i.deleted_at&.iso8601,
        created_at:        i.created_at.iso8601,
        updated_at:        i.updated_at.iso8601
      }
    end

    def person_ref(user)
      return nil if user.nil?
      { id: user.id.to_s, name: user.name }
    end

    def category_ref(category)
      return nil if category.nil?
      { id: category.id.to_s, name: category.name, account_code: category.account_code }
    end

    def account_ref(account)
      { id: account.id.to_s, name: account.name }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
