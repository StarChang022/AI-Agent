module Api
  # 一般支出 CRUD endpoints。全部要求 JWT + role=admin（後台功能），並限定於
  # 呼叫者所屬 company。對應 frontend/src/api/expenses.ts 契約。
  #
  # 本 controller 做 source='general'（行政直接登錄）的 CRUD + 付款狀態切換。
  # source='reimbursement'（核准代墊款轉入）的連動建立留待後續模組。
  class ExpensesController < ApplicationController
    # update / adjust_payout_date 寫入 AuditLog 時，只對這些欄位做 diff（避免 serialized
    # jsonb 以外的 noise 進 log）。planned_payout_* 由 adjust_payout_date 覆寫，paid_at
    # 由 update 走 partial path 時可能被改——都算一般欄位更新。
    AUDITED_UPDATE_FIELDS = %w[
      document_type vendor tax_id invoice_no tax_rate
      pre_tax_amt tax_amt amount date note attachments items
      category_id paid_at planned_payout_date planned_payout_manual
    ].freeze

    before_action :require_admin
    before_action :set_expense, only: %i[show update destroy pay revert_pay adjust_payout_date]
    before_action :set_discarded_expense, only: %i[restore purge]

    # 分頁預設；pageSize 對齊前端 ROWS_OPTIONS 第一個選項 (10)，上限 100 防誤傳巨值。
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    # GET /api/expenses?discarded=&source=&category_ids[]=&payout_status=&date_from=&date_to=&q=&page=&per_page=
    # 預設只回未刪；discarded=true → 回垃圾桶（已軟刪的）。其餘 filter 兩種情境共用。
    # 垃圾桶預設依 deleted_at 新到舊；正常列表依費用日新到舊。
    # q 對 vendor / note / invoice_no 三欄 OR ILIKE。
    #
    # 回傳 { data: [...], meta: { total, page, pageSize } }，為 list endpoint
    # 的通用信封；單筆 endpoint（show/create/update/pay...）仍直接回單一物件。
    def index
      discarded = discarded_only?
      scope = current_user.company.expenses
      scope = discarded ? scope.discarded : scope.kept
      scope = scope.includes(:category, :created_by, :paid_by)
      scope = scope.where(source:        params[:source])        if params[:source].present?
      scope = scope.where(payout_status: params[:payout_status]) if params[:payout_status].present?
      scope = scope.where(category_id:   Array(params[:category_ids])) if params[:category_ids].present?
      scope = scope.where("date >= ?",   params[:date_from])     if params[:date_from].present?
      scope = scope.where("date <= ?",   params[:date_to])       if params[:date_to].present?

      if params[:q].present?
        kw = "%#{params[:q].to_s.strip}%"
        scope = scope.where(
          "vendor ILIKE :kw OR note ILIKE :kw OR invoice_no ILIKE :kw",
          kw: kw
        )
      end

      scope = discarded ? scope.order(deleted_at: :desc) : scope.order(date: :desc, created_at: :desc)

      page      = [params[:page].to_i, 1].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [page_size, MAX_PAGE_SIZE].min
      total     = scope.count

      records = scope.limit(page_size).offset((page - 1) * page_size)
      render json: {
        data: records.map { |e| list_serialize(e) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # GET /api/expenses/:id
    def show
      render json: serialize(@expense)
    end

    # GET /api/expenses/pending-batches
    # 待付款支出依 planned_payout_date 分組；逾期（< today）合併為一組 overdue。
    # 給支出頁「待付款」tab 的付款批次視圖用；一次吐全部 pending（不分頁），
    # 避免前端為了分組邏輯要用 perPage=100 這類脆弱上限。
    #
    # 回傳 shape（groups 依 overdue 在最前、其餘 date asc）：
    # {
    #   groups: [
    #     { key: "0000-overdue" | "YYYY-MM-DD", date: "YYYY-MM-DD" | null,
    #       overdue: bool, total: number, source_meta: { general, reimbursement },
    #       rows: ExpenseSummary[] }
    #   ]
    # }
    # date：overdue 組取組內最早的 planned_payout_date（可能為 nil）；非 overdue 等於 key。
    # 公司未設 payout_day 時回空陣列（前端自行決定如何呈現；一般走非分組視圖）。
    def pending_batches
      today = Date.current
      scope = current_user.company.expenses.kept
        .where(payout_status: "pending")
        .includes(:category, :created_by, :paid_by)
        .order(Arel.sql("COALESCE(planned_payout_date, '9999-12-31') ASC, created_at DESC"))

      overdue_rows = []
      by_date = {}
      scope.find_each do |e|
        iso = e.planned_payout_date
        if iso.nil? || iso < today
          overdue_rows << e
        else
          (by_date[iso] ||= []) << e
        end
      end

      groups = []
      if overdue_rows.any?
        groups << build_batch_group("0000-overdue", overdue_rows, overdue: true)
      end
      by_date.keys.sort.each do |iso|
        groups << build_batch_group(iso.iso8601, by_date[iso], overdue: false, date: iso)
      end

      render json: { groups: groups }
    end

    # POST /api/expenses
    # source 固定 'general'（後端寫死）；payout_status='paid' → 立即寫入 paid_at
    # （client 可帶 paid_at 覆寫、否則為今天）與 paid_by（當前使用者）。
    # 未帶或 'pending' → 建立為待付款，寫入 planned_payout_date 快照。
    # 建立後要切換狀態走 /pay / /revert-pay 專用 endpoint，不走 PATCH。
    def create
      category = current_user.company.categories.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
      return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "expense"

      initial_status = params[:payout_status].presence || "pending"
      return render_error("INVALID_PAYOUT_STATUS", :unprocessable_content) unless Expense::PAYOUT_STATUSES.include?(initial_status)

      expense = current_user.company.expenses.new(created_by: current_user, source: "general", category: category)
      assign_fields(expense)
      if initial_status == "paid"
        expense.payout_status = "paid"
        expense.paid_at       = parse_paid_at || Date.current
        expense.paid_by       = current_user
      else
        snapped = PayoutSchedule.snapshot(Date.current, current_user.company.payout_day)
        expense.payout_status            = "pending"
        expense.planned_payout_date      = snapped
        expense.auto_planned_payout_date = snapped
        expense.planned_payout_manual    = false
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = expense.save
        AuditLog.record!(expense, action: "create", by: current_user, after: expense_snapshot(expense)) if saved
      end

      if saved
        render json: serialize(expense), status: :created
      else
        render json: validation_error(expense), status: :unprocessable_content
      end
    end

    # PATCH /api/expenses/:id
    # partial：只覆寫 client 傳來的欄位。payout_status 本身仍走 pay / revert_pay；
    # 但若已為 paid，可透過本 endpoint 修改 paid_at（例如更正撥款日），paid_by 不異動。
    def update
      if params.key?(:category_id)
        category = current_user.company.categories.find_by(id: params[:category_id])
        return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
        return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "expense"
        @expense.category = category
      end

      assign_fields(@expense)

      if params.key?(:paid_at) && @expense.payout_status == "paid"
        new_paid_at = parse_paid_at
        return render_error("PAID_AT_REQUIRED", :unprocessable_content) if new_paid_at.nil?
        @expense.paid_at = new_paid_at
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = @expense.save
        audit_update_change!(@expense) if saved
      end

      if saved
        render json: serialize(@expense)
      else
        render json: validation_error(@expense), status: :unprocessable_content
      end
    end

    # DELETE /api/expenses/:id?void_reimbursement=true&void_comment=...
    # 軟刪，進垃圾桶（寫入 deleted_at）。
    # - 已付款（paid）→ 擋，需先切回 pending 再刪。
    # - 代墊款來源（source=reimbursement）→ 可選是否連帶把對應代墊款作廢。
    #   連帶作廢時必帶 void_comment（作廢原因必填）；代墊款狀態必須在
    #   VOIDABLE_STATUSES 內（in_review / rejected / approved）。
    def destroy
      return render_error("PAID_NOT_DELETABLE", :conflict) if @expense.payout_status == "paid"

      void_linked = ActiveModel::Type::Boolean.new.cast(params[:void_reimbursement]) == true
      comment     = params[:void_comment].to_s.strip
      reimbursement = nil

      if void_linked
        return render_error("NOT_REIMBURSEMENT_SOURCED", :unprocessable_content) unless @expense.source == "reimbursement"
        return render_error("COMMENT_REQUIRED", :unprocessable_content) if comment.blank?
        reimbursement = current_user.company.reimbursements.find_by(id: @expense.source_ref_id)
        return render_error("REIMBURSEMENT_NOT_FOUND", :unprocessable_content) if reimbursement.nil?
        return render_error("INVALID_STATE", :conflict) unless Reimbursement::VOIDABLE_STATUSES.include?(reimbursement.status)
      end

      ActiveRecord::Base.transaction do
        @expense.discard!
        AuditLog.record!(@expense, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @expense.deleted_at&.iso8601 })

        if reimbursement
          prev_status = reimbursement.status
          reimbursement.status = "voided"
          reimbursement.push_event!(type: "void", by: current_user.id, comment: comment)
          reimbursement.save!
          AuditLog.record!(reimbursement, action: "void", by: current_user,
            before: { status: prev_status },
            after:  { status: "voided", comment: comment })
        end
      end

      render json: {}, status: :ok
    end

    # PATCH /api/expenses/:id/restore
    # 從垃圾桶還原：清掉 deleted_at，狀態保留（原本是 pending 就回 pending）。
    def restore
      prev_deleted_at = @expense.deleted_at&.iso8601
      ActiveRecord::Base.transaction do
        @expense.restore_from_trash!
        AuditLog.record!(@expense, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
      end
      render json: serialize(@expense)
    end

    # DELETE /api/expenses/:id/purge
    # 永久刪除：真的 DELETE。前端須已做二次確認。audit log 必須在 destroy! 前寫入，
    # 否則 target.company 連動撈不到（record 已消失）。
    def purge
      ActiveRecord::Base.transaction do
        AuditLog.record!(@expense, action: "purge", by: current_user, before: expense_snapshot(@expense))
        @expense.destroy!
      end
      render json: {}, status: :ok
    end

    # PATCH /api/expenses/:id/pay
    # 付款這筆支出，記錄 paid_at（client 可帶、否則為今天）與 paid_by（當前使用者）。
    # 若來源是代墊款（source='reimbursement'），視為「撥款給員工」，必須帶 payment_method
    # （'bank_transfer' | 'cash'），寫入連動的代墊款（Reimbursement.payment_method）；
    # 一般支出（source='general'）不要求、也不儲存發放方式。
    def pay
      paid_on = parse_paid_at || Date.current
      method  = parse_payment_method

      if @expense.source == "reimbursement" && method.nil?
        return render_error("PAYMENT_METHOD_REQUIRED", :unprocessable_content)
      end

      synced_reimbursement = nil
      ActiveRecord::Base.transaction do
        prev_paid_at    = @expense.paid_at&.iso8601
        prev_paid_by_id = @expense.paid_by_id&.to_s
        @expense.update!(payout_status: "paid", paid_at: paid_on, paid_by: current_user)
        AuditLog.record!(@expense, action: "status_change", by: current_user,
          before: { payout_status: "pending", paid_at: prev_paid_at, paid_by_id: prev_paid_by_id },
          after:  { payout_status: "paid",    paid_at: paid_on.iso8601, paid_by_id: current_user.id.to_s })
        synced_reimbursement = sync_linked_reimbursement(@expense, "paid", from: "approved", paid_at: paid_on, payment_method: method)
      end
      Notifications.notify_paid(synced_reimbursement, paid_at: paid_on) if synced_reimbursement
      render json: serialize(@expense)
    end

    # PATCH /api/expenses/:id/revert-pay
    # 取消付款：改為 pending，**保留** paid_at / paid_by（規格要求資料不清空、
    # 僅由前端依 payout_status 決定是否顯示；再度切回 paid 時可沿用）。
    # 代墊款來源者連帶把對應代墊款退回 approved；代墊款的 paid_at/paid_by/payment_method
    # 亦同步保留（history 不推事件）。
    #
    # 若這筆從未當 pending 處理過（建立時直接選已付款，auto_planned_payout_date 仍為
    # NULL），revert 當下用「今天 + 公司當前 payout_day」補 snapshot，寫入 planned 與
    # auto 兩欄；已有 auto 值者則不動（維持「auto 寫入後不變」的語意）。
    def revert_pay
      ActiveRecord::Base.transaction do
        preserved_paid_at = @expense.paid_at&.iso8601
        attrs  = { payout_status: "pending" }
        before = { payout_status: "paid",    paid_at: preserved_paid_at }
        after  = { payout_status: "pending", paid_at: preserved_paid_at }
        if @expense.auto_planned_payout_date.nil?
          snapped = PayoutSchedule.snapshot(Date.current, @expense.company.payout_day)
          attrs.merge!(planned_payout_date: snapped, auto_planned_payout_date: snapped, planned_payout_manual: false)
          before.merge!(planned_payout_date: nil, auto_planned_payout_date: nil)
          after.merge!(planned_payout_date: snapped&.iso8601, auto_planned_payout_date: snapped&.iso8601)
        end
        @expense.update!(attrs)
        AuditLog.record!(@expense, action: "status_change", by: current_user, before: before, after: after)
        sync_linked_reimbursement(@expense, "approved", from: "paid")
      end
      render json: serialize(@expense)
    end

    # PATCH /api/expenses/:id/adjust-payout-date
    # body: { date: 'yyyy-mm-dd' | null }
    # - date 有值 → 寫入 planned_payout_date 並鎖定（planned_payout_manual=true）；
    #   不動 auto_planned_payout_date（登錄時 snapshot 的原自動值）。
    # - date 為 null → 用 auto_planned_payout_date 還原 planned_payout_date 並解除鎖定；
    #   不重算快照，確保「改回自動排程」拿到的永遠是這筆支出的原始自動值，不會因公司
    #   規則變動而漂移。
    # 僅 pending 可調（paid 已實際撥款、voided 已廢；前端已擋，後端補一層）。
    def adjust_payout_date
      return render_error("INVALID_STATE", :conflict) unless @expense.payout_status == "pending"

      ActiveRecord::Base.transaction do
        if params.key?(:date) && params[:date].present?
          new_date = parse_date(params[:date])
          return render_error("INVALID_DATE", :unprocessable_content) if new_date.nil?
          @expense.update!(planned_payout_date: new_date, planned_payout_manual: true)
        else
          @expense.update!(planned_payout_date: @expense.auto_planned_payout_date, planned_payout_manual: false)
        end
        audit_update_change!(@expense)
      end
      render json: serialize(@expense)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_expense
      @expense = current_user.company.expenses.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @expense.nil?
    end

    # restore / purge 走垃圾桶，找 discarded 的那筆。
    def set_discarded_expense
      @expense = current_user.company.expenses.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @expense.nil?
    end

    # 填入可編輯欄位；只處理 client 有帶的 key（create 會全帶、update 為 partial）。
    # 不含 source / created_by / company / payout_status（各有專屬處理）。
    def assign_fields(e)
      e.document_type = params[:document_type]              if params.key?(:document_type)
      e.vendor        = params[:vendor].presence            if params.key?(:vendor)
      e.tax_id        = params[:tax_id].presence            if params.key?(:tax_id)
      e.invoice_no    = params[:invoice_no].presence        if params.key?(:invoice_no)
      e.tax_rate      = params[:tax_rate]                   if params.key?(:tax_rate)
      e.pre_tax_amt   = parse_amount(params[:pre_tax_amt])  if params.key?(:pre_tax_amt)
      e.tax_amt       = parse_amount(params[:tax_amt])      if params.key?(:tax_amt)
      e.amount        = parse_amount(params[:amount])       if params.key?(:amount)
      e.date          = params[:date]                       if params.key?(:date)
      e.note          = params[:note].presence             if params.key?(:note)
      e.attachments   = json_array(params[:attachments])   if params.key?(:attachments)
      e.items         = json_array(params[:items])          if params.key?(:items)
    end

    # index 用：discarded=true → 垃圾桶（已軟刪）；未帶或 false → 正常列表。
    def discarded_only?
      ActiveModel::Type::Boolean.new.cast(params[:discarded]) == true
    end

    # 代墊款來源的支出改付款狀態時，連帶同步對應代墊款（僅在來源狀態吻合時才動，避免誤改）。
    # - pay：paid_at / payment_method 必帶，寫入並推 'pay' 事件。
    # - revert：**保留** paid_at / paid_by / payment_method（規格要求），只回退 status。
    def sync_linked_reimbursement(expense, to_status, from:, paid_at: nil, payment_method: nil)
      return unless expense.source == "reimbursement" && expense.source_ref_id.present?

      reimbursement = expense.company.reimbursements.find_by(id: expense.source_ref_id)
      return nil if reimbursement.nil? || reimbursement.status != from

      if to_status == "paid"
        reimbursement.paid_at        = paid_at
        reimbursement.paid_by        = current_user
        reimbursement.payment_method = payment_method
        reimbursement.push_event!(type: "pay", by: current_user.id, at: paid_at)
      end
      reimbursement.status = to_status
      reimbursement.save!

      # 代墊款連動 audit：pay 寫入 paid_at + payment_method；revert 僅記 status（paid_at
      # 依規格保留，before/after 不列出，避免 UI 誤判為「有變更」）。
      after_payload = { status: to_status }
      if to_status == "paid"
        after_payload[:paid_at]        = paid_at&.iso8601
        after_payload[:payment_method] = payment_method
      end
      AuditLog.record!(reimbursement, action: "status_change", by: current_user,
        before: { status: from },
        after:  after_payload)

      reimbursement
    end

    # paid_at 參數解析：接受 'yyyy-mm-dd' 字串；格式錯誤或空字串回 nil。
    def parse_paid_at
      raw = params[:paid_at]
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # 一般日期字串解析（yyyy-mm-dd）；空字串或格式錯誤回 nil。
    def parse_date(raw)
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # payment_method 解析：僅接受 Reimbursement 白名單值；格式錯誤或空字串回 nil
    # （由呼叫端決定是否必填）。欄位本體掛在 Reimbursement 上。
    def parse_payment_method
      raw = params[:payment_method].to_s
      Reimbursement::PAYMENT_METHODS.include?(raw) ? raw : nil
    end

    def parse_amount(raw)
      return nil if raw.nil? || raw == ""
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    # 把巢狀 JSON 陣列（ActionController::Parameters）轉成純 hash 供 jsonb 儲存。
    def json_array(raw)
      return [] if raw.blank?
      Array(raw).map { |el| el.respond_to?(:to_unsafe_h) ? el.to_unsafe_h : el }
    end

    # 單筆 endpoint（show/create/update/pay/revert_pay/adjust_payout_date/restore）
    # 回全欄位；含可能很大的 attachments（jsonb data_url）與 items（jsonb 品項）。
    def serialize(e)
      {
        id:                  e.id.to_s,
        source:              e.source,
        source_ref_id:       e.source_ref_id&.to_s,
        document_type:       e.document_type,
        vendor:              e.vendor,
        tax_id:              e.tax_id,
        invoice_no:          e.invoice_no,
        tax_rate:            e.tax_rate,
        pre_tax_amt:         e.pre_tax_amt&.to_f,
        tax_amt:             e.tax_amt&.to_f,
        amount:              e.amount.to_f,
        category:            category_ref(e.category),
        date:                e.date.iso8601,
        note:                e.note,
        attachments:         e.attachments,
        items:               e.items,
        payout_status:              e.payout_status,
        planned_payout_date:        e.planned_payout_date&.iso8601,
        planned_payout_manual:      e.planned_payout_manual,
        auto_planned_payout_date:   e.auto_planned_payout_date&.iso8601,
        paid_at:               e.paid_at&.iso8601,
        paid_by:             person_ref(e.paid_by),
        created_by:          person_ref(e.created_by),
        deleted_at:          e.deleted_at&.iso8601,
        created_at:          e.created_at.iso8601,
        updated_at:          e.updated_at.iso8601
      }
    end

    # 列表精簡序列化：砍掉 attachments 與 items（憑證 base64 一筆可能數 MB，
    # 乘上一頁 10 筆就會非常重）；auto_planned_payout_date 也不送（只有詳情抽屜
    # 的「改回自動排程」才需要，列表不顯示）。前端對應 ExpenseSummary 型別；
    # 開詳情抽屜時另外打 /expenses/:id 取 full serialize。
    def list_serialize(e)
      serialize(e).except(:attachments, :items, :auto_planned_payout_date)
    end

    # 付款批次群組；pending_batches 用。
    # overdue=true 時 date 取組內最早的 planned_payout_date（可能為 nil，代表組內
    # 全是「無預計付款日」的 pending）；非 overdue 直接等於 key。
    def build_batch_group(key, rows, overdue:, date: nil)
      earliest = rows.map(&:planned_payout_date).compact.min
      effective_date = overdue ? earliest : date
      general = rows.count { |r| r.source == "general" }
      {
        key:         key,
        date:        effective_date&.iso8601,
        overdue:     overdue,
        total:       rows.sum(&:amount).to_f,
        source_meta: { general: general, reimbursement: rows.length - general },
        rows:        rows.map { |e| list_serialize(e) }
      }
    end

    # 人員引用（PersonRef）：對齊前端 types/domain.ts#PersonRef。
    # 顯示用 .name、邏輯比對用 .id；user 為 nil 時回 nil。
    def person_ref(user)
      return nil if user.nil?
      { id: user.id.to_s, name: user.name }
    end

    # 類別引用（CategoryRef）：對齊前端 types/domain.ts#CategoryRef。
    # 顯示用 .name、分組對比用 .id；category 不應為 nil（Expense 必綁類別）。
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

    # create / purge 用：寫入 AuditLog 的核心快照（business-level 欄位，不含內部 id 格式）。
    def expense_snapshot(e)
      {
        source:        e.source,
        source_ref_id: e.source_ref_id&.to_s,
        vendor:        e.vendor,
        amount:        e.amount&.to_f,
        date:          e.date&.iso8601,
        category_id:   e.category_id&.to_s,
        category_name: e.category&.name,
        note:          e.note,
        payout_status: e.payout_status,
        paid_at:       e.paid_at&.iso8601
      }
    end

    # update / adjust_payout_date 用：對 AUDITED_UPDATE_FIELDS 做 saved_changes diff，
    # 有變更才寫 log（避免「只有 updated_at 動」的空 log）。必須在 save 完成的同一
    # transaction 內呼叫，不然 saved_changes 會被下一次 reload 清掉。
    def audit_update_change!(e)
      diff = e.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      AuditLog.record!(e, action: "update", by: current_user,
        before: diff.transform_values { |(old, _)| old },
        after:  diff.transform_values { |(_, new)| new })
    end
  end
end
