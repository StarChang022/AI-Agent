module Api
  # 收入 CRUD endpoints。全部要求 JWT + role=admin（後台功能），並限定於
  # 呼叫者所屬 company。鏡像 ExpensesController，差異：
  # - customer（必填）取代 vendor；無 source / source_ref_id（代墊款不轉成收入）
  # - 收款相關為 collection_status / collected_at（對應 payout_status / paid_at）
  # - 無 planned_payout_date / planned_payout_manual（§2.6 未定義預計收款日欄位）
  # - 無 paid_by 類人員欄位（§2.6 未定義 received_by）
  class IncomesController < ApplicationController
    # update 寫入 AuditLog 時只對這些欄位做 diff（jsonb 以外的 noise 不入 log）。
    # collected_at 由 update 走 partial path 時可能被改——算一般欄位更新。
    AUDITED_UPDATE_FIELDS = %w[
      document_type customer tax_id invoice_no tax_rate
      pre_tax_amt tax_amt amount date note attachments items
      category_id collected_at
    ].freeze

    before_action :require_admin
    before_action :set_income, only: %i[show update destroy collect revert_collect]
    before_action :set_discarded_income, only: %i[restore purge]

    # GET /api/incomes?discarded=&category_ids[]=&collection_status=&date_from=&date_to=&q=
    # 預設只回未刪；discarded=true → 回垃圾桶。
    # 垃圾桶預設依 deleted_at 新到舊；正常列表依開立日新到舊。
    # q 對 customer / note / invoice_no 三欄 OR ILIKE。
    def index
      discarded = discarded_only?
      scope = current_user.company.incomes
      scope = discarded ? scope.discarded : scope.kept
      scope = scope.includes(:category, :created_by)
      scope = scope.where(collection_status: params[:collection_status]) if params[:collection_status].present?
      scope = scope.where(category_id:       Array(params[:category_ids])) if params[:category_ids].present?
      scope = scope.where("date >= ?",       params[:date_from])         if params[:date_from].present?
      scope = scope.where("date <= ?",       params[:date_to])           if params[:date_to].present?

      if params[:q].present?
        kw = "%#{params[:q].to_s.strip}%"
        scope = scope.where(
          "customer ILIKE :kw OR note ILIKE :kw OR invoice_no ILIKE :kw",
          kw: kw
        )
      end

      scope = discarded ? scope.order(deleted_at: :desc) : scope.order(date: :desc, created_at: :desc)
      render json: scope.map { |i| serialize(i) }
    end

    # GET /api/incomes/:id
    def show
      render json: serialize(@income)
    end

    # POST /api/incomes
    # collection_status='collected' → 立即寫入 collection_status + collected_at
    # （client 可帶 collected_at 覆寫，否則為今天）。
    # 未帶或 'uncollected' → 建立為待收款。狀態之後要切換走 /collect / /revert-collect。
    def create
      category = current_user.company.categories.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
      return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "income"

      initial_status = params[:collection_status].presence || "uncollected"
      return render_error("INVALID_COLLECTION_STATUS", :unprocessable_content) unless Income::COLLECTION_STATUSES.include?(initial_status)

      income = current_user.company.incomes.new(created_by: current_user, category: category)
      assign_fields(income)
      if initial_status == "collected"
        income.collection_status = "collected"
        income.collected_at      = parse_collected_at || Date.current
      else
        income.collection_status = "uncollected"
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = income.save
        AuditLog.record!(income, action: "create", by: current_user, after: income_snapshot(income)) if saved
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
        category = current_user.company.categories.find_by(id: params[:category_id])
        return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
        return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "income"
        @income.category = category
      end

      assign_fields(@income)

      if params.key?(:collected_at) && @income.collection_status == "collected"
        new_collected_at = parse_collected_at
        return render_error("COLLECTED_AT_REQUIRED", :unprocessable_content) if new_collected_at.nil?
        @income.collected_at = new_collected_at
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = @income.save
        audit_update_change!(@income) if saved
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
    def restore
      prev_deleted_at = @income.deleted_at&.iso8601
      ActiveRecord::Base.transaction do
        @income.restore_from_trash!
        AuditLog.record!(@income, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
      end
      render json: serialize(@income)
    end

    # DELETE /api/incomes/:id/purge
    # 永久刪除：真的 DELETE。前端須已做二次確認。audit log 必須在 destroy! 前寫入，
    # 否則 target.company 連動撈不到（record 已消失）。
    def purge
      ActiveRecord::Base.transaction do
        AuditLog.record!(@income, action: "purge", by: current_user, before: income_snapshot(@income))
        @income.destroy!
      end
      render json: {}, status: :ok
    end

    # PATCH /api/incomes/:id/collect
    # 標記為已收款：collected_at（client 可帶、否則今天）。
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

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_income
      @income = current_user.company.incomes.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @income.nil?
    end

    # restore / purge 走垃圾桶，找 discarded 的那筆。
    def set_discarded_income
      @income = current_user.company.incomes.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @income.nil?
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
      i.note          = params[:note].presence              if params.key?(:note)
      i.attachments   = json_array(params[:attachments])    if params.key?(:attachments)
      i.items         = json_array(params[:items])          if params.key?(:items)
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

    def serialize(i)
      {
        id:                i.id.to_s,
        document_type:     i.document_type,
        customer:          i.customer,
        tax_id:            i.tax_id,
        invoice_no:        i.invoice_no,
        tax_rate:          i.tax_rate,
        pre_tax_amt:       i.pre_tax_amt&.to_f,
        tax_amt:           i.tax_amt&.to_f,
        amount:            i.amount.to_f,
        category:          category_ref(i.category),
        date:              i.date.iso8601,
        note:              i.note,
        attachments:       i.attachments,
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

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end

    # create / purge 用：business-level 快照（不含內部 jsonb/序號等 noise）。
    def income_snapshot(i)
      {
        customer:          i.customer,
        amount:            i.amount&.to_f,
        date:              i.date&.iso8601,
        category_id:       i.category_id&.to_s,
        category_name:     i.category&.name,
        note:              i.note,
        collection_status: i.collection_status,
        collected_at:      i.collected_at&.iso8601
      }
    end

    # update 用：對 AUDITED_UPDATE_FIELDS 做 saved_changes diff，有變更才寫 log。
    # 必須在 save 完成的同一 transaction 內呼叫，不然 saved_changes 會被 reload 清掉。
    def audit_update_change!(i)
      diff = i.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      AuditLog.record!(i, action: "update", by: current_user,
        before: diff.transform_values { |(old, _)| old },
        after:  diff.transform_values { |(_, new)| new })
    end
  end
end
