require "csv"
require "axlsx"

module Api
  # 代墊款請款 CRUD endpoints。操作者為「申請人本人」：全部限定於
  # current_user 自己的請款（擁有者隔離），不分 admin / employee。
  #
  # 本 controller 只負責 CRUD；簽核 / 撥款 / 作廢等狀態轉移為後續模組。
  # 建立與編輯可帶 as_draft：true → 存草稿（draft）、false → 送審（in_review，
  # 並產生單層「管理員簽核」進度）。可編輯 / 刪除僅限 draft、rejected。
  class ReimbursementsController < ApplicationController
    # update 寫入 AuditLog 時只對這些欄位做 diff。status / approval_progress / version
    # 是狀態機衍生欄位，另走 status_change log，不列入一般 update。
    AUDITED_UPDATE_FIELDS = %w[
      category_id amount description incurred_at
      receipt_urls receipt_names
      document_type vendor tax_id invoice_no tax_rate
      pre_tax_amt tax_amt
    ].freeze

    # 匯出報表用的狀態中文；需要跟前端 constants/expense.ts STATUS_LABELS 對齊。
    EXPORT_STATUS_LABELS = {
      "draft"     => "草稿",
      "in_review" => "簽核中",
      "rejected"  => "駁回",
      "approved"  => "已核銷",
      "paid"      => "已發放",
      "voided"    => "已作廢"
    }.freeze

    before_action :set_reimbursement, only: %i[show update destroy withdraw]

    # 分頁預設；pageSize 對齊前端 ROWS_OPTIONS 第一個選項 (10)，上限 100 防誤傳巨值。
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    # GET /api/reimbursements?status=&statuses[]=&q=&category_ids[]=&date_from=&date_to=&amount_min=&amount_max=&page=&per_page=
    # 前台「我的請款」歷史頁；回申請人自己的全部請款，新到舊。
    # 單一員工資料量小，保留 receipt_urls / receipt_names 讓 HistoryView 卡片顯示縮圖；
    # 只砍 history（可成長）。回傳 { data: [...], meta: { total, page, pageSize } }。
    # statuses[] 多狀態 OR 支援 HistoryView「待處理」(rejected+draft) /「完成」(paid+voided)
    # 這類複合 tab；若同時傳 status 單值 statuses[] 優先。
    def index
      scope = current_user.reimbursements.includes(:category, :employee, :paid_by, :expense)
      if params[:statuses].present?
        scope = scope.where(status: Array(params[:statuses]))
      elsif params[:status].present?
        scope = scope.where(status: params[:status])
      end
      scope = apply_list_filters(scope).order(created_at: :desc)

      render json: paginated_response(scope) { |r| my_list_item(r) }
    end

    # GET /api/reimbursements/admin?status=&employee_id=&q=&category_ids[]=&date_from=&date_to=&amount_min=&amount_max=&pending_for_me=&reviewed_by_me=&page=&per_page=
    # 後台列表（審核 / 紀錄頁共用）：回公司全部請款，排除他人草稿（visible scope）。
    # Top-N 用法（例：Dashboard 待簽核前 5 筆）改用 per_page=5，不再支援獨立 limit 參數。
    # ReviewView 走 pending_for_me / reviewed_by_me 定位「我該簽 / 我處理過」。
    def admin
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      scope = current_user.company.reimbursements.visible.includes(:category, :employee, :paid_by, :expense)
      scope = scope.where(status: params[:status])           if params[:status].present?
      scope = scope.where(employee_id: params[:employee_id]) if params[:employee_id].present?
      scope = scope.pending_for(current_user.id)             if truthy_param?(:pending_for_me)
      scope = scope.reviewed_by_user(current_user.id)        if truthy_param?(:reviewed_by_me)
      scope = apply_list_filters(scope).order(created_at: :desc)

      render json: paginated_response(scope) { |r| admin_list_item(r) }
    end

    # GET /api/reimbursements/my-summary
    # 前台 HomeView KPI：一次打包回當前員工自己的匯總（金額加總 + 筆數 +
    # 最近一筆已發放 + 最近 4 筆任何狀態），避免首頁打多次 API。
    def my_summary
      scope = current_user.reimbursements

      totals = {
        in_review: scope.where(status: "in_review").sum(:amount).to_f,
        approved:  scope.where(status: "approved").sum(:amount).to_f,
        paid:      scope.where(status: "paid").sum(:amount).to_f
      }
      counts = {
        all:      scope.count,
        rejected: scope.where(status: "rejected").count
      }

      last_paid_rec = scope.where(status: "paid").order(updated_at: :desc).first
      last_paid =
        if last_paid_rec
          {
            id:         last_paid_rec.id.to_s,
            amount:     last_paid_rec.amount.to_f,
            updated_at: last_paid_rec.updated_at.iso8601
          }
        end

      # recent 用 admin_list_item shape（砍 receipts）：HomeView 卡片不顯示縮圖，省 payload
      recent = scope.includes(:category, :employee, :paid_by, :expense)
                    .order(created_at: :desc).limit(4)

      render json: {
        totals:    totals,
        counts:    counts,
        last_paid: last_paid,
        recent:    recent.map { |r| admin_list_item(r) }
      }
    end

    # GET /api/reimbursements/export?format=csv|xlsx (& 同 admin 的全部 filter)
    # 匯出目前篩選的全部請款（不分頁）；admin only。
    # format 預設 csv；無資料時仍回有表頭的空檔案（不是 204）。
    def export
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      format = params[:format].to_s.downcase
      format = "csv" unless %w[csv xlsx].include?(format)

      scope = current_user.company.reimbursements.visible.includes(:category, :employee, :paid_by, :expense)
      scope = scope.where(status: params[:status])           if params[:status].present?
      scope = scope.where(employee_id: params[:employee_id]) if params[:employee_id].present?
      scope = scope.pending_for(current_user.id)             if truthy_param?(:pending_for_me)
      scope = scope.reviewed_by_user(current_user.id)        if truthy_param?(:reviewed_by_me)
      scope = apply_list_filters(scope).order(created_at: :desc)

      rows = scope.to_a
      if format == "xlsx"
        send_export_xlsx(rows)
      else
        send_export_csv(rows)
      end
    end

    # GET /api/reimbursements/:id
    def show
      render json: serialize(@reimbursement)
    end

    # POST /api/reimbursements
    # body: { category_id, amount, description, incurred_at, receipt_urls[], receipt_names[],
    #         document_type, vendor, tax_id, invoice_no, tax_rate, pre_tax_amt, tax_amt, as_draft }
    # category_id 為 draft 專屬可空；送審 (as_draft=false) 時必填。
    def create
      status   = draft_param? ? "draft" : "in_review"
      category = resolve_category_param(allow_nil: status == "draft")
      return if performed? # resolve_category_param 失敗時已 render

      reimbursement = current_user.company.reimbursements.new(employee: current_user)
      assign_fields(reimbursement, category)
      reimbursement.status = status
      reimbursement.approval_progress = (status == "in_review" ? build_approval_progress : nil)
      reimbursement.push_event!(type: "submit", by: current_user.id) if status == "in_review"

      saved = false
      ActiveRecord::Base.transaction do
        saved = reimbursement.save
        AuditLog.record!(reimbursement, action: "create", by: current_user, after: reimbursement_snapshot(reimbursement)) if saved
      end

      if saved
        Notifications.notify_submitted(reimbursement) if reimbursement.status == "in_review"
        render json: serialize(reimbursement), status: :created
      else
        render json: validation_error(reimbursement), status: :unprocessable_content
      end
    end

    # PATCH /api/reimbursements/:id
    # 僅 draft / rejected 可編輯。rejected 一律重新送審（in_review）；draft 依 as_draft。
    def update
      return render_error("NOT_EDITABLE", :conflict) unless @reimbursement.editable?

      status =
        if @reimbursement.status == "rejected"
          "in_review" # 駁回後沒有「存回草稿」語意，只能重送
        else
          draft_param? ? "draft" : "in_review"
        end

      category = resolve_category_param(allow_nil: status == "draft")
      return if performed?

      from_status = @reimbursement.status
      assign_fields(@reimbursement, category)
      @reimbursement.status = status
      @reimbursement.approval_progress = (status == "in_review" ? build_approval_progress : nil)
      @reimbursement.version = @reimbursement.version + 1

      if status == "in_review"
        event_type = from_status == "rejected" ? "resubmit" : "submit"
        @reimbursement.push_event!(type: event_type, by: current_user.id)
      end

      saved = false
      ActiveRecord::Base.transaction do
        saved = @reimbursement.save
        if saved
          audit_update_change!(@reimbursement)
          if from_status != status
            AuditLog.record!(@reimbursement, action: "status_change", by: current_user,
              before: { status: from_status },
              after:  { status: status })
          end
        end
      end

      if saved
        Notifications.notify_submitted(@reimbursement) if status == "in_review"
        render json: serialize(@reimbursement)
      else
        render json: validation_error(@reimbursement), status: :unprocessable_content
      end
    end

    # DELETE /api/reimbursements/:id
    # 僅 draft / rejected 可刪除（申請人放棄）。規格第 18 條：代墊款不走垃圾桶，
    # 這條路徑是「申請人撤回未送出的申請」，不涉金流、不影響統計，不寫 AuditLog。
    def destroy
      return render_error("NOT_EDITABLE", :conflict) unless @reimbursement.editable?

      @reimbursement.destroy!
      render json: {}, status: :ok
    end

    # PATCH /api/reimbursements/:id/approve
    # 管理員核准（in_review → approved），核准當下自動建立對應的一般支出
    # （source='reimbursement'、payout_status='pending'）並回填雙向關聯。
    # 撥款不在此：之後於「支出付款」(Expense#pay) 連帶把本筆設為 paid。
    def approve
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      reimbursement = current_user.company.reimbursements.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if reimbursement.nil?
      return render_error("INVALID_STATE", :conflict) unless reimbursement.status == "in_review"

      ActiveRecord::Base.transaction do
        expense = build_linked_expense(reimbursement)
        expense.save!
        # 代墊款核准連動產生的 expense 沒走 ExpensesController，必須在這裡補 create log
        AuditLog.record!(expense, action: "create", by: current_user, after: expense_snapshot(expense))

        reimbursement.status            = "approved"
        reimbursement.expense_id        = expense.id
        reimbursement.approval_progress = approved_progress(reimbursement)
        reimbursement.push_event!(type: "approve", by: current_user.id, stage: "管理員簽核", comment: params[:comment])
        reimbursement.save!
        AuditLog.record!(reimbursement, action: "status_change", by: current_user,
          before: { status: "in_review" },
          after:  { status: "approved", expense_id: expense.id.to_s, comment: params[:comment] })
      end

      Notifications.notify_approved(reimbursement.reload)
      render json: serialize(reimbursement)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/reimbursements/:id/void
    # 管理員作廢。限 VOIDABLE_STATUSES（in_review / rejected / approved）；
    # paid 已實際撥款，需先 Expense#revert_pay 才能作廢。comment 必填。
    #
    # body: { comment, delete_expense }
    # delete_expense=true → 若已核准（有對應 expense），連帶把那筆支出軟刪進垃圾桶；
    # 已被軟刪或尚未建立則略過。
    def void
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      reimbursement = current_user.company.reimbursements.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if reimbursement.nil?
      return render_error("INVALID_STATE", :conflict) unless Reimbursement::VOIDABLE_STATUSES.include?(reimbursement.status)

      comment = params[:comment].to_s.strip
      return render_error("COMMENT_REQUIRED", :unprocessable_content) if comment.blank?

      delete_expense = ActiveModel::Type::Boolean.new.cast(params[:delete_expense]) == true

      ActiveRecord::Base.transaction do
        prev_status = reimbursement.status
        reimbursement.status = "voided"
        reimbursement.push_event!(type: "void", by: current_user.id, comment: comment)
        reimbursement.save!
        AuditLog.record!(reimbursement, action: "void", by: current_user,
          before: { status: prev_status },
          after:  { status: "voided", comment: comment })

        if delete_expense && reimbursement.expense_id.present?
          expense = current_user.company.expenses.kept.find_by(id: reimbursement.expense_id)
          if expense
            expense.discard!
            AuditLog.record!(expense, action: "delete", by: current_user,
              before: { deleted_at: nil },
              after:  { deleted_at: expense.deleted_at&.iso8601 })
          end
        end
      end

      render json: serialize(reimbursement)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/reimbursements/:id/withdraw
    # 申請人取消簽核（in_review → draft），清空 approval_progress 讓 draft 可繼續編輯或刪除。
    # 不需要 comment。版本（version）不動。
    def withdraw
      return render_error("INVALID_STATE", :conflict) unless @reimbursement.status == "in_review"

      ActiveRecord::Base.transaction do
        @reimbursement.status            = "draft"
        @reimbursement.approval_progress = nil
        @reimbursement.push_event!(type: "withdraw", by: current_user.id)
        @reimbursement.save!
        AuditLog.record!(@reimbursement, action: "status_change", by: current_user,
          before: { status: "in_review" },
          after:  { status: "draft" })
      end

      render json: serialize(@reimbursement)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/reimbursements/:id/revert-void
    # 管理員取消作廢（voided → approved）。無 comment 需求；UI 把它當 undo 用。
    # 不自動還原已被連帶軟刪的對應支出 — 若需要，使用者自行到支出垃圾桶還原。
    def revert_void
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      reimbursement = current_user.company.reimbursements.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if reimbursement.nil?
      return render_error("INVALID_STATE", :conflict) unless reimbursement.status == "voided"

      ActiveRecord::Base.transaction do
        reimbursement.status = "approved"
        reimbursement.push_event!(type: "revert_void", by: current_user.id)
        reimbursement.save!
        AuditLog.record!(reimbursement, action: "status_change", by: current_user,
          before: { status: "voided" },
          after:  { status: "approved" })
      end

      render json: serialize(reimbursement)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/reimbursements/:id/reject
    # 管理員駁回（in_review → rejected），駁回意見必填。
    # 不建立對應支出；員工可編輯後 resubmit（走完整簽核）。對齊前端 rejectCurrentStep。
    def reject
      return render_error("forbidden", :forbidden) unless current_user&.role_admin?

      reimbursement = current_user.company.reimbursements.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if reimbursement.nil?
      return render_error("INVALID_STATE", :conflict) unless reimbursement.status == "in_review"

      comment = params[:comment].to_s.strip
      return render_error("COMMENT_REQUIRED", :unprocessable_content) if comment.blank?

      ActiveRecord::Base.transaction do
        reimbursement.status            = "rejected"
        reimbursement.approval_progress = rejected_progress(reimbursement, comment)
        reimbursement.push_event!(type: "reject", by: current_user.id, stage: "管理員簽核", comment: comment)
        reimbursement.save!
        AuditLog.record!(reimbursement, action: "status_change", by: current_user,
          before: { status: "in_review" },
          after:  { status: "rejected", comment: comment })
      end

      Notifications.notify_rejected(reimbursement, comment: comment)
      render json: serialize(reimbursement)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    private

    def set_reimbursement
      @reimbursement = current_user.reimbursements.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @reimbursement.nil?
    end

    # index / admin 共用的列表篩選：關鍵字、類別、費用日區間、金額區間。
    # 關鍵字 q：對 vendor / description / invoice_no 三欄 OR 比對（ILIKE）。
    # category_ids：陣列 → `IN (...)`；前端以 `category_ids[]=a&category_ids[]=b` 送。
    def apply_list_filters(scope)
      if params[:q].present?
        kw = "%#{params[:q].to_s.strip}%"
        scope = scope.where(
          "vendor ILIKE :kw OR description ILIKE :kw OR invoice_no ILIKE :kw",
          kw: kw
        )
      end

      if params[:category_ids].present?
        scope = scope.where(category_id: Array(params[:category_ids]))
      end

      if params[:date_from].present? || params[:date_to].present?
        from = params[:date_from].presence
        to   = params[:date_to].presence
        scope = scope.where("incurred_at >= ?", from) if from
        scope = scope.where("incurred_at <= ?", to)   if to
      end

      if params[:amount_min].present? || params[:amount_max].present?
        min = params[:amount_min].presence
        max = params[:amount_max].presence
        scope = scope.where("amount >= ?", min) if min
        scope = scope.where("amount <= ?", max) if max
      end

      scope
    end

    # 填入申請人可編輯的欄位（不含 employee / company / status / approval_progress）。
    # category / amount / incurred_at 容許 nil（draft 專屬），presence 由 model 層把關。
    def assign_fields(reimbursement, category)
      reimbursement.category      = category
      reimbursement.amount        = parse_amount(params[:amount])
      reimbursement.description   = params[:description].to_s
      reimbursement.incurred_at   = params[:incurred_at].presence
      reimbursement.receipt_urls  = string_array(params[:receipt_urls])
      reimbursement.receipt_names = string_array(params[:receipt_names])
      reimbursement.document_type = params[:document_type]
      reimbursement.vendor        = params[:vendor].presence
      reimbursement.tax_id        = params[:tax_id].presence
      reimbursement.invoice_no    = params[:invoice_no].presence
      reimbursement.tax_rate      = params[:tax_rate]
      reimbursement.pre_tax_amt   = parse_amount(params[:pre_tax_amt])
      reimbursement.tax_amt       = parse_amount(params[:tax_amt])
    end

    # 送審時的簽核進度：單層「管理員簽核」，候選人為公司所有 admin。
    # 邏輯對齊前端 utils/approval.ts#buildApprovalProgress（含 admin 自提時排除自己）。
    # key 以 snake_case 儲存，前端 api/service.ts 會自動轉回 camelCase。
    def build_approval_progress
      admin_ids = current_user.company.users.where(role: "admin").pluck(:id).map(&:to_s)
      candidates =
        if current_user.role_admin?
          others = admin_ids - [ current_user.id.to_s ]
          others.any? ? others : [ current_user.id.to_s ]
        else
          admin_ids
        end

      {
        "current_step" => 1,
        "steps" => [
          {
            "order"       => 1,
            "stage_name"  => "管理員簽核",
            "candidates"  => candidates,
            "status"      => "pending",
            "reviewed_by" => nil,
            "comment"     => nil,
            "reviewed_at" => nil
          }
        ]
      }
    end

    def draft_param?
      ActiveModel::Type::Boolean.new.cast(params[:as_draft]) == true
    end

    def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(params[key]) == true
    end

    # 解析 params[:category_id]；查無或非 expense 類別時 render 錯誤並回 nil。
    # allow_nil=true 時（draft）允許 category_id 不帶，回 nil；非 draft 不填會
    # 由上層以 CATEGORY_REQUIRED 擋下（或直接讓 model presence 驗證失敗）。
    def resolve_category_param(allow_nil:)
      if params[:category_id].blank?
        unless allow_nil
          render_error("CATEGORY_REQUIRED", :unprocessable_content)
          return nil
        end
        return nil
      end

      cat = current_user.company.categories.find_by(id: params[:category_id])
      if cat.nil?
        render_error("CATEGORY_NOT_FOUND", :unprocessable_content)
        return nil
      end
      unless cat.kind == "expense"
        render_error("CATEGORY_WRONG_KIND", :unprocessable_content)
        return nil
      end
      cat
    end

    # 由代墊款建立對應的一般支出（對齊前端 stores/expenses.ts#addFromReimbursement）。
    # planned_payout_date 以「核准當下」為登錄基準快照（不是請款發生日 incurred_at，
    # 也不是請款提交時間），符合「進帳本的時間 = 核准成立時間」的語意。
    def build_linked_expense(r)
      snapped = PayoutSchedule.snapshot(Date.current, r.company.payout_day)
      current_user.company.expenses.new(
        source:                   "reimbursement",
        source_ref_id:            r.id,
        created_by:               current_user,
        category:                 r.category,
        document_type:            r.document_type,
        vendor:                   expense_vendor_for(r),
        tax_id:                   r.tax_id,
        invoice_no:               r.invoice_no,
        tax_rate:                 r.tax_rate,
        pre_tax_amt:              r.pre_tax_amt,
        tax_amt:                  r.tax_amt,
        amount:                   r.amount,
        date:                     r.incurred_at,
        note:                     r.description,
        attachments:              reimbursement_attachments(r),
        items:                    [],
        payout_status:            "pending",
        planned_payout_date:      snapped,
        auto_planned_payout_date: snapped,
        planned_payout_manual:    false
      )
    end

    # 廠商顯示為「員工姓名（廠商）」；無廠商則只有員工姓名（對齊前端 buildExpenseVendor）。
    def expense_vendor_for(r)
      name   = r.employee.name
      vendor = r.vendor.to_s.strip
      vendor.present? ? "#{name}（#{vendor}）" : name
    end

    # receipt_urls[] → ExpenseAttachment[]（snake_case 存 jsonb，前端讀時 service.ts 轉 camelCase）。
    def reimbursement_attachments(r)
      urls  = r.receipt_urls  || []
      names = r.receipt_names || []
      urls.each_with_index.map do |data_url, i|
        {
          "data_url"  => data_url,
          "filename"  => names[i].presence || "receipt-#{i + 1}",
          "mime_type" => guess_mime_type(data_url)
        }
      end
    end

    def guess_mime_type(data_url)
      m = data_url.to_s.match(/\Adata:([^;]+);/)
      m ? m[1] : "application/octet-stream"
    end

    # 回傳把「當前簽核步驟」標記為已通過的 approval_progress（單層，由本次核准者簽）。
    def approved_progress(r)
      progress = r.approval_progress
      return progress if progress.blank?

      idx  = (progress["current_step"] || 1) - 1
      step = progress["steps"]&.[](idx)
      if step
        step["status"]      = "approved"
        step["reviewed_by"] = current_user.id.to_s
        step["reviewed_at"] = Time.current.iso8601
        step["comment"]     = params[:comment]
      end
      progress
    end

    # 回傳把「當前簽核步驟」標記為駁回的 approval_progress（comment 由呼叫端 trim 後傳入）。
    def rejected_progress(r, comment)
      progress = r.approval_progress
      return progress if progress.blank?

      idx  = (progress["current_step"] || 1) - 1
      step = progress["steps"]&.[](idx)
      if step
        step["status"]      = "rejected"
        step["reviewed_by"] = current_user.id.to_s
        step["reviewed_at"] = Time.current.iso8601
        step["comment"]     = comment
      end
      progress
    end

    def parse_amount(raw)
      return nil if raw.nil? || raw == ""
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def string_array(raw)
      Array(raw).map(&:to_s)
    end

    # index / admin 共用：套用 page / per_page（夾在 1..MAX_PAGE_SIZE）後回分頁信封。
    # 呼叫端用 block 指定每筆的序列化（admin → admin_list_item、index → my_list_item）。
    def paginated_response(scope, &serializer)
      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      records = scope.limit(page_size).offset((page - 1) * page_size)
      {
        data: records.map(&serializer),
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # 後台列表序列化：砍 receipt_urls / receipt_names（憑證 base64 一筆可能數 MB，
    # 乘上公司上百筆非常重）與 history（可成長的事件陣列）。
    # 前端對應 ReimbursementSummary 型別；詳情抽屜另打 /reimbursements/:id 取 full serialize。
    def admin_list_item(r)
      serialize(r).except(:receipt_urls, :receipt_names, :history)
    end

    # 前台「我的請款」列表序列化：資料量小（單一員工自己的紀錄），保留 receipt_urls /
    # receipt_names 讓卡片顯示縮圖；仍砍 history（可成長）。前端對應 MyReimbursementSummary。
    def my_list_item(r)
      serialize(r).except(:history)
    end

    def serialize(r)
      cache = user_name_cache_for(r)
      {
        id:                r.id.to_s,
        employee:          person_ref(r.employee),
        amount:            r.amount.to_f,
        category:          category_ref(r.category),
        description:       r.description,
        incurred_at:       r.incurred_at.iso8601,
        receipt_urls:      r.receipt_urls,
        receipt_names:     r.receipt_names,
        document_type:     r.document_type,
        vendor:            r.vendor,
        tax_id:            r.tax_id,
        invoice_no:        r.invoice_no,
        tax_rate:          r.tax_rate,
        pre_tax_amt:       r.pre_tax_amt&.to_f,
        tax_amt:           r.tax_amt&.to_f,
        status:            r.status,
        approval_progress: serialize_approval_progress(r.approval_progress, cache),
        expense_id:        r.expense_id&.to_s,
        linked_expense:    linked_expense_ref(r.expense),
        paid_at:           r.paid_at&.iso8601,
        paid_by:           person_ref(r.paid_by),
        payment_method:    r.payment_method,
        history:           serialize_history(r.history || [], cache),
        version:           r.version,
        created_at:        r.created_at.iso8601,
        updated_at:        r.updated_at.iso8601
      }
    end

    # 人員引用（PersonRef）：對齊前端 types/domain.ts#PersonRef。
    # 顯示用 .name、邏輯比對用 .id；user 為 nil 時回 nil。
    def person_ref(user)
      return nil if user.nil?
      { id: user.id.to_s, name: user.name }
    end

    # 類別引用（CategoryRef）：對齊前端 types/domain.ts#CategoryRef。
    def category_ref(category)
      return nil if category.nil?
      { id: category.id.to_s, name: category.name, account_code: category.account_code }
    end

    # 對應支出摘要：給前端 ReimbursementDetail / useReimbursementPayout 用。
    # 僅帶顯示付款狀態與預計發放日所需欄位，避免整個 Expense 都塞進 Reimbursement payload。
    def linked_expense_ref(expense)
      return nil if expense.nil?
      {
        id:                   expense.id.to_s,
        payout_status:        expense.payout_status,
        planned_payout_date:  expense.planned_payout_date&.iso8601
      }
    end

    # 從 jsonb 內的 user id 字串還原為 PersonRef，名字查 cache，查無時以空字串填入
    # （整列仍顯示 id，前端 UI 自行決定如何呈現未知使用者）。
    def person_ref_from_id(id, cache)
      return nil if id.blank?
      { id: id.to_s, name: cache[id.to_s].to_s }
    end

    # 一次性查出此筆 reimbursement 的 history / approval_progress 內所有 user id 的名字，
    # 避免 serialize_history / serialize_approval_progress 每筆再打 DB。
    def user_name_cache_for(r)
      ids = []
      (r.history || []).each { |e| ids << e["by"] if e["by"].present? }
      if r.approval_progress.is_a?(Hash)
        (r.approval_progress["steps"] || []).each do |s|
          ids << s["reviewed_by"] if s["reviewed_by"].present?
        end
      end
      return {} if ids.empty?
      User.where(id: ids.uniq).pluck(:id, :name).to_h.transform_keys(&:to_s)
    end

    # approval_progress.steps[].reviewed_by 由 id 字串展開成 PersonRef；
    # 其餘欄位（order、stage_name、candidates、status、comment、reviewed_at）原樣保留。
    def serialize_approval_progress(progress, cache)
      return nil if progress.blank?
      steps = (progress["steps"] || []).map do |s|
        s.merge("reviewed_by" => person_ref_from_id(s["reviewed_by"], cache))
      end
      progress.merge("steps" => steps)
    end

    # history[].by 由 id 字串展開成 PersonRef；缺 by 鍵（系統事件）時填 nil 保持 shape 一致。
    def serialize_history(events, cache)
      events.map do |e|
        e.merge("by" => person_ref_from_id(e["by"], cache))
      end
    end

    # 匯出欄位組裝；CSV / XLSX 共用，避免兩邊各寫一份走偏。
    def export_row(r)
      [
        r.employee&.name,
        r.description,
        r.category&.name,
        r.amount&.to_f,
        r.incurred_at&.iso8601,
        EXPORT_STATUS_LABELS[r.status] || r.status,
        r.created_at.iso8601
      ]
    end

    EXPORT_HEADERS = %w[申請人 說明 類別 金額 費用日 狀態 建立時間].freeze

    def send_export_csv(rows)
      csv = CSV.generate do |c|
        c << EXPORT_HEADERS
        rows.each { |r| c << export_row(r) }
      end
      # 前綴 UTF-8 BOM，Excel 開啟 CSV 才不會亂碼。
      send_data "\xEF\xBB\xBF#{csv}".b,
        filename: "請款記錄_#{Date.current.iso8601}.csv",
        type: "text/csv; charset=utf-8",
        disposition: "attachment"
    end

    def send_export_xlsx(rows)
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "請款記錄") do |sheet|
        sheet.add_row EXPORT_HEADERS
        rows.each { |r| sheet.add_row export_row(r) }
      end
      send_data package.to_stream.read,
        filename: "請款記錄_#{Date.current.iso8601}.xlsx",
        type: Mime[:xlsx].to_s,
        disposition: "attachment"
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end

    # create / void 用：代墊款的 business-level 快照（不含內部 jsonb/序號等 noise）。
    def reimbursement_snapshot(r)
      {
        employee_id:   r.employee_id&.to_s,
        employee_name: r.employee&.name,
        amount:        r.amount&.to_f,
        category_id:   r.category_id&.to_s,
        category_name: r.category&.name,
        description:   r.description,
        incurred_at:   r.incurred_at&.iso8601,
        status:        r.status,
        vendor:        r.vendor,
        expense_id:    r.expense_id&.to_s
      }
    end

    # update 時對 AUDITED_UPDATE_FIELDS 做 saved_changes diff，有變更才寫 log。
    # 必須在 save 完成的同一 transaction 內呼叫，不然 saved_changes 會被 reload 清掉。
    def audit_update_change!(r)
      diff = r.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      AuditLog.record!(r, action: "update", by: current_user,
        before: diff.transform_values { |(old, _)| old },
        after:  diff.transform_values { |(_, new)| new })
    end

    # approve 連動建立的 expense 要補 create log（shape 對齊 ExpensesController#expense_snapshot）。
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
  end
end
