module Api
  # 一般支出 CRUD endpoints。全部要求 JWT + role=admin（後台功能），並限定於
  # 呼叫者所屬 company。對應 frontend/src/api/expenses.ts 契約。
  #
  # 本 controller 做 source='general'（行政直接登錄）的 CRUD + 付款狀態切換。
  # source='reimbursement'（核准代墊款轉入）的連動建立留待後續模組。
  class ExpensesController < ApplicationController
    include AccountParam
    include RecordAttachments

    # update / adjust_payout_date 寫入 AuditLog 時，只對這些欄位做 diff（避免 serialized
    # jsonb 以外的 noise 進 log）。planned_payout_* 由 adjust_payout_date 覆寫，paid_at
    # 由 update 走 partial path 時可能被改——都算一般欄位更新。
    AUDITED_UPDATE_FIELDS = %w[
      document_type vendor tax_id invoice_no tax_rate
      pre_tax_amt tax_amt amount date invoice_date note items
      category_id account_id paid_at planned_payout_date planned_payout_manual
    ].freeze

    before_action :require_admin
    before_action :require_company_account, only: :create
    before_action :set_any_expense, only: :show
    before_action :set_expense, only: %i[update destroy pay revert_pay adjust_payout_date]
    before_action :set_editable_expense, only: :destroy_attachment
    before_action :set_discarded_expense, only: %i[restore purge]
    before_action :reject_transfer_fee, only: %i[update destroy pay revert_pay adjust_payout_date]

    # 分頁預設；pageSize 對齊前端 ROWS_OPTIONS 第一個選項 (10)，上限 100 防誤傳巨值。
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    # GET /api/expenses?discarded=&source=general|reimbursement|recurring|transfer_fee&missing_invoice_no=&category_ids[]=&payout_status=&date_from=&date_to=&q=&page=&per_page=
    # 預設只回未刪；discarded=true → 回垃圾桶（已軟刪的）。其餘 filter 兩種情境共用。
    # missing_invoice_no=true → 只看文件類型為發票、發票號碼空白的紀錄。
    # 垃圾桶預設依 deleted_at 新到舊；正常列表依發生日期新到舊。
    # q 對 vendor / note / invoice_no 三欄 OR ILIKE。
    #
    # 回傳 { data: [...], meta: { total, page, pageSize } }，為 list endpoint
    # 的通用信封；單筆 endpoint（show/create/update/pay...）仍直接回單一物件。
    def index
      discarded = discarded_only?
      scope = current_user.company.expenses
      scope = discarded ? scope.discarded : scope.kept
      scope = scope.includes(:category, :account, :created_by, :paid_by, :source_reimbursement, :current_fee_transfer)
      # 篩選與期間匯出共用（RecordFilters）
      scope = RecordFilters.expenses(scope, params)

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
    # 垃圾桶內的也查得到（回傳 deleted_at、deleted_by），比照移轉；編輯、狀態切換仍只限垃圾桶外。
    def show
      deleted_by = AuditLog.deleted_by_map(current_user.company, "expense", [ @expense.id ])[@expense.id] if @expense.discarded?
      render json: serialize(@expense, deleted_by: deleted_by)
    end

    # GET /api/expenses/pending-batches
    # 待付款支出依應付日期（planned_payout_date）分組；逾期（< 公司時區今天）合併為一組 overdue。
    # 給支出頁「待付款」tab 的付款批次視圖用；一次吐全部 pending（不分頁），
    # 避免前端為了分組邏輯要用 perPage=100 這類脆弱上限。
    #
    # 回傳 shape（groups 依 overdue 在最前、其餘 date asc）：
    # {
    #   groups: [
    #     { key: "0000-overdue" | "YYYY-MM-DD", date: "YYYY-MM-DD" | null,
    #       overdue: bool, total: number, count: number, source_meta: { general, reimbursement },
    #       rows: ExpenseSummary[] }
    #   ]
    # }
    # date：overdue 組取組內最早的應付日期；非 overdue 等於 key。公司關閉付款日時照樣分組。
    def pending_batches
      scope = current_user.company.expenses.kept
        .where(payout_status: "pending")
        .includes(:category, :account, :created_by, :paid_by, :source_reimbursement, :current_fee_transfer)
        .order(:planned_payout_date, created_at: :desc)

      groups = PendingBatches.group(scope.to_a, date_of: :planned_payout_date.to_proc) do |rows|
        general = rows.count { |r| r.source == "general" }
        { source_meta: { general: general, reimbursement: rows.length - general },
          rows: rows.map { |e| list_serialize(e) } }
      end
      render json: { groups: groups }
    end

    # POST /api/expenses
    # source 固定 'general'（後端寫死）；payout_status='paid' → 立即寫入 paid_at
    # （client 可帶 paid_at 覆寫、否則為今天）與 paid_by（當前使用者）。
    # 不論狀態，都以今天為登錄日依付款日算出應付日期的自動值；client 帶的 planned_payout_date
    # 與自動值（關閉付款日時為發生日期）不同時視為手動修改。
    # 建立後要切換狀態走 /pay / /revert-pay 專用 endpoint，不走 PATCH。
    def create
      category = current_user.company.categories.selectable.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
      return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "expense"

      account = find_account_param
      return if performed?

      initial_status = params[:payout_status].presence || "pending"
      return render_error("INVALID_PAYOUT_STATUS", :unprocessable_content) unless Expense::PAYOUT_STATUSES.include?(initial_status)

      expense = current_user.company.expenses.new(created_by: current_user, source: "general", category: category, account: account)
      assign_fields(expense)
      blobs = claim_attachments(expense)
      expense.snapshot_planned_payout!(Date.current)
      assign_planned_payout(expense)
      return if performed?
      if initial_status == "paid"
        expense.payout_status = "paid"
        expense.paid_at       = parse_paid_at || Date.current
        expense.paid_by       = current_user
      else
        expense.payout_status = "pending"
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = expense.save
        if saved
          attach_claimed!(expense, blobs)
          AuditLog.record!(expense, action: "create", by: current_user, after: expense.audit_snapshot)
        end
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
    # planned_payout_date 任何狀態都可改；送 null 等於改回自動排程。沒手動改過的應付日期
    # 由 model 跟著發生日期（見 Expense#follow_default_planned_payout_date）。
    def update
      if params.key?(:category_id)
        category = current_user.company.categories.selectable(@expense.category_id).find_by(id: params[:category_id])
        return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?
        return render_error("CATEGORY_WRONG_KIND", :unprocessable_content) unless category.kind == "expense"
        @expense.category = category
      end

      if params.key?(:account_id)
        account = find_account_param
        return if performed?
        @expense.account = account
      end

      assign_fields(@expense)
      assign_planned_payout(@expense)
      return if performed?
      blobs = claim_attachments(@expense)

      if params.key?(:paid_at) && @expense.payout_status == "paid"
        new_paid_at = parse_paid_at
        return render_error("PAID_AT_REQUIRED", :unprocessable_content) if new_paid_at.nil?
        @expense.paid_at = new_paid_at
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = @expense.save
        if saved
          attachments_change = attach_claimed!(@expense, blobs)
          audit_update_with_attachments!(@expense, AUDITED_UPDATE_FIELDS, attachments_change)
          sync_linked_paid_at!(@expense)
        end
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

      reimbursement = ExpenseTrash.voidable_reimbursement!(@expense, params[:void_comment]) if void_reimbursement_param?

      ActiveRecord::Base.transaction do
        @expense.discard!
        AuditLog.record!(@expense, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @expense.deleted_at&.iso8601 })

        ExpenseTrash.void_reimbursement!(reimbursement, by: current_user, comment: params[:void_comment]) if reimbursement
      end

      render json: {}, status: :ok
    end

    # PATCH /api/expenses/:id/restore
    # 從垃圾桶還原：清掉 deleted_at，狀態保留（原本是 pending 就回 pending）。
    # 手續費支出 → 409 TRANSFER_FEE_LOCKED；來源代墊款已作廢 → 409 REIMBURSEMENT_VOIDED。
    # 規則在 ExpenseTrash，批次還原共用。
    def restore
      ExpenseTrash.restore!(@expense, by: current_user)
      render json: serialize(@expense)
    end

    # DELETE /api/expenses/:id/purge?void_reimbursement=true&void_comment=...
    # 永久刪除：真的 DELETE。前端須已做二次確認。audit log 必須在 destroy! 前寫入，
    # 否則 target.company 連動撈不到（record 已消失）。
    # 連帶作廢來源代墊款的參數與驗證同 destroy；但來源代墊款尚可作廢時為必選
    # （422 VOID_REQUIRED），避免留下沒有支出、永遠無法撥款的已核准代墊款。
    # 移轉目前對應的手續費支出 → 409 TRANSFER_FEE_LOCKED。規則在 ExpenseTrash，批次永久刪除共用。
    def purge
      ExpenseTrash.purge!(@expense, by: current_user,
        void_reimbursement: void_reimbursement_param?, void_comment: params[:void_comment])
      render json: {}, status: :ok
    end

    # POST /api/expenses/batch_restore   body: { ids: [...] }
    # 每筆各自依單筆還原規則處理，一筆失敗不影響其他筆（docs/dev/trash-batch-api.md）。
    def batch_restore
      ids = TrashActions.parse_ids(params[:ids])
      result = TrashActions.run_batch(trash_scope, ids) do |e|
        ExpenseTrash.restore!(e, by: current_user)
      end
      render json: result
    end

    # POST /api/expenses/batch_purge   body: { ids: [...], void_comment? }
    # 來源代墊款尚可作廢的那幾筆用 void_comment 一起作廢；沒帶或空白 → 這幾筆列 VOID_REQUIRED，其他照刪。
    def batch_purge
      ids     = TrashActions.parse_ids(params[:ids])
      comment = params[:void_comment].to_s.strip
      result = TrashActions.run_batch(trash_scope, ids) do |e|
        void = comment.present? && ExpenseTrash.void_required?(e)
        ExpenseTrash.purge!(e, by: current_user, void_reimbursement: void, void_comment: comment)
      end
      render json: result
    end

    # PATCH /api/expenses/:id/pay
    # 付款這筆支出，記錄 paid_at（client 帶確認視窗的日期、沒帶為今天）與 paid_by（當前使用者）。
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
    # 亦同步保留（history 不推事件）。應付日期不變（PRD 第 10 條）。
    def revert_pay
      ActiveRecord::Base.transaction do
        paid_on = @expense.paid_at
        @expense.update!(payout_status: "pending")

        before = { payout_status: "paid",    paid_at: paid_on&.iso8601 }
        after  = { payout_status: "pending", paid_at: paid_on&.iso8601 }
        AuditLog.record!(@expense, action: "status_change", by: current_user, before: before, after: after)
        sync_linked_reimbursement(@expense, "approved", from: "paid")
      end
      render json: serialize(@expense)
    end

    # PATCH /api/expenses/:id/adjust-payout-date
    # body: { date: 'yyyy-mm-dd' | null }
    # - date 有值 → 寫入 planned_payout_date；與自動值不同時 planned_payout_manual=true。
    #   不動 auto_planned_payout_date（登錄時 snapshot 的原自動值）。
    # - date 為 null → 改回自動排程：還原為 auto_planned_payout_date；不重算快照，確保
    #   「改回自動排程」拿到的永遠是這筆支出的原始自動值，不會因公司規則變動而漂移。
    #   登錄／核准當下公司已關閉付款日（auto_planned_payout_date 為 null）的支出沒有自動
    #   排程可回，回 409 NO_AUTO_SCHEDULE、不改資料（2026-11-11 定案）。
    # 僅 pending 可調（paid 已實際撥款、voided 已廢；前端已擋，後端補一層）。
    def adjust_payout_date
      return render_error("INVALID_STATE", :conflict) unless @expense.payout_status == "pending"

      ActiveRecord::Base.transaction do
        if params.key?(:date) && params[:date].present?
          new_date = parse_date(params[:date])
          return render_error("INVALID_DATE", :unprocessable_content) if new_date.nil?
          @expense.assign_planned_payout_date(new_date)
        else
          if @expense.auto_planned_payout_date.nil?
            return render json: { error: "NO_AUTO_SCHEDULE", message: "這筆支出登錄時沒有付款日，無法改回自動排程" },
                          status: :conflict
          end
          @expense.assign_planned_payout_date(nil)
        end
        @expense.save!
        audit_update_change!(@expense)
      end
      render json: serialize(@expense)
    end

    # DELETE /api/expenses/:id/attachments/:attachment_id
    # 編輯頁刪除已存圖檔，立即永久刪除（docs/dev/attachments-api.md 第 4 節）。代墊款核准產生的支出
    # 只從支出拿掉，代墊款保留原圖。
    def destroy_attachment
      remove_attachment!(@expense)
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

    def set_any_expense
      @expense = current_user.company.expenses.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @expense.nil?
    end

    # 刪圖檔：垃圾桶內的紀錄不能編輯；手續費支出的憑證在移轉上。
    def set_editable_expense
      @expense = current_user.company.expenses.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if @expense.nil?
      return render_in_trash if @expense.discarded?
      render_transfer_fee_locked if @expense.transfer_fee?
    end

    # restore / purge 走垃圾桶，找 discarded 的那筆。
    def set_discarded_expense
      @expense = current_user.company.expenses.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @expense.nil?
    end

    # 手續費支出只能經由移轉異動（PRD 第 19 條）。
    def reject_transfer_fee
      render_transfer_fee_locked if @expense.transfer_fee?
    end

    def render_transfer_fee_locked
      render json: { error: "TRANSFER_FEE_LOCKED", message: "這筆手續費由資金移轉管理，要修改請到移轉" }, status: :conflict
    end

    # destroy / purge 的 void_reimbursement 參數（是否連帶作廢來源代墊款）。
    def void_reimbursement_param?
      ActiveModel::Type::Boolean.new.cast(params[:void_reimbursement]) == true
    end

    # 批次用：本公司垃圾桶內的支出。
    def trash_scope
      current_user.company.expenses.discarded.includes(:source_reimbursement, :current_fee_transfer)
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
      e.invoice_date  = params[:invoice_date].presence      if params.key?(:invoice_date)
      e.note          = params[:note].presence             if params.key?(:note)
      e.items         = json_array(params[:items])          if params.key?(:items)
    end

    # 應付日期參數：有帶才處理，須在 assign_fields（發生日期）之後。null 或空字串 = 改回自動排程。
    # 編輯時前端一律連同應付日期送出；值和更新前相同視為沒改，手動狀態不變，跟隨規則照常運作。
    def assign_planned_payout(e)
      return unless params.key?(:planned_payout_date)
      raw = params[:planned_payout_date]
      return e.assign_planned_payout_date(nil) if raw.blank?

      value = parse_date(raw)
      return render_error("INVALID_DATE", :unprocessable_content) if value.nil?
      return if e.persisted? && value == e.planned_payout_date_in_database
      e.assign_planned_payout_date(value)
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

    # 已付款的代墊款來源支出改了付款日 → 連動代墊款的 paid_at 一起改（發放日須與付款日一致）。
    # 不推新的 history 事件、不重寄通知；改寫最後一筆 pay 事件的日期讓時間軸的發放日一致，
    # 舊值留在 audit log。須在 update 的 transaction 內、save 之後呼叫。
    def sync_linked_paid_at!(expense)
      return unless expense.source == "reimbursement" && expense.saved_change_to_paid_at?

      reimbursement = expense.company.reimbursements.find_by(id: expense.source_ref_id)
      return if reimbursement.nil? || reimbursement.status != "paid"

      prev_paid_at = reimbursement.paid_at
      reimbursement.paid_at = expense.paid_at
      last_pay = reimbursement.history.rindex { |e| e["type"] == "pay" }
      if last_pay
        reimbursement.history = reimbursement.history.each_with_index.map do |e, i|
          i == last_pay ? e.merge("at" => expense.paid_at.iso8601) : e
        end
      end
      reimbursement.save!
      AuditLog.record!(reimbursement, action: "update", by: current_user,
        before: { paid_at: prev_paid_at&.iso8601 },
        after:  { paid_at: expense.paid_at.iso8601 })
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
    # 回全欄位；含圖檔與 items（jsonb 品項）。
    # deleted_by：垃圾桶的操作人（最新一筆刪除稽核的操作者），只有單筆查詢會查；其餘為 nil。
    def serialize(e, deleted_by: nil)
      summary_fields(e).merge(deleted_by: person_ref(deleted_by), attachments: AttachmentFiles.as_json(e, current_user))
    end

    # 圖檔以外的欄位；列表不查圖檔，避免每筆多打查詢。
    def summary_fields(e)
      {
        id:                  e.id.to_s,
        source:              e.source,
        source_ref_id:       e.source_ref_id&.to_s,
        recurring_template_id: e.recurring_template_id&.to_s,
        recurring_period:    e.recurring_period,
        transfer_id:         e.transfer_id&.to_s,
        restorable:          !e.transfer_fee?,
        purgeable:           e.current_fee_transfer.nil?,
        document_type:       e.document_type,
        vendor:              e.vendor,
        tax_id:              e.tax_id,
        invoice_no:          e.invoice_no,
        tax_rate:            e.tax_rate,
        pre_tax_amt:         e.pre_tax_amt&.to_f,
        tax_amt:             e.tax_amt&.to_f,
        amount:              e.amount.to_f,
        category:            category_ref(e.category),
        account:             account_ref(e.account),
        date:                e.date.iso8601,
        invoice_date:        e.invoice_date&.iso8601,
        note:                e.note,
        items:               e.items,
        payout_status:              e.payout_status,
        planned_payout_date:        e.planned_payout_date&.iso8601,
        planned_payout_manual:      e.planned_payout_manual,
        auto_planned_payout_date:   e.auto_planned_payout_date&.iso8601,
        paid_at:               e.paid_at&.iso8601,
        paid_by:             person_ref(e.paid_by),
        created_by:          person_ref(e.created_by),
        deleted_at:          e.deleted_at&.iso8601,
        # 來源代墊款目前狀態；一般支出為 nil。前端據此決定刪除時是否詢問連帶作廢。
        source_reimbursement_status: e.source_reimbursement&.status,
        created_at:          e.created_at.iso8601,
        updated_at:          e.updated_at.iso8601
      }
    end

    # 列表精簡序列化：不帶圖檔與 items。auto_planned_payout_date 要帶：列表的調整應付日期
    # 視窗用它判斷能不能改回自動排程。前端對應 ExpenseSummary 型別；
    # 開詳情抽屜時另外打 /expenses/:id 取 full serialize。
    def list_serialize(e)
      summary_fields(e).except(:items)
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

    def account_ref(account)
      { id: account.id.to_s, name: account.name }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end

    # adjust_payout_date 用：對 AUDITED_UPDATE_FIELDS 做 saved_changes diff，
    # 有變更才寫 log（避免「只有 updated_at 動」的空 log）。必須在 save 完成的同一
    # transaction 內呼叫，不然 saved_changes 會被下一次 reload 清掉。
    def audit_update_change!(e)
      diff = e.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      before, after = AuditLog.update_payload(diff)
      AuditLog.record!(e, action: "update", by: current_user, before: before, after: after)
    end
  end
end
