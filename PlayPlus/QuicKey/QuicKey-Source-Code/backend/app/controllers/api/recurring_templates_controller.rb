module Api
  # 固定收支範本（PRD 第 17 條）。全部要求 JWT + role=admin，並限定於呼叫者所屬 company。
  # 合約見 docs/dev/recurring-api.md。驗證錯誤的 type 就是 API 的錯誤代碼。
  class RecurringTemplatesController < ApplicationController
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    CONFLICT_CODES = [ "START_MONTH_LOCKED", *RecurringTemplate::CATEGORY_BLOCK_MESSAGES.keys ].freeze
    SCHEDULE_FIELDS = %i[frequency day_of_month month_of_year start_month end_month].freeze
    EDITABLE_FIELDS = %i[name category_id account_id document_type tax_rate counterparty tax_id amount] + SCHEDULE_FIELDS
    AUDITED_UPDATE_FIELDS = EDITABLE_FIELDS.map(&:to_s).freeze

    before_action :require_admin
    before_action :set_template, only: %i[update destroy]
    before_action :set_any_template, only: %i[show records]
    before_action :set_discarded_template, only: %i[restore purge]

    # GET /api/recurring-templates?direction=&tab=&page=&per_page=
    # 進行中、歷史是即時計算的，範本筆數也不多，所以全部載入後分組再分頁。
    # meta.counts 回全部分頁的數量，不受 direction、tab 影響。
    def index
      direction = params[:direction].to_s
      unless RecurringTemplate::DIRECTIONS.include?(direction)
        return render_error("INVALID_DIRECTION", "請選擇固定收入或固定支出", :unprocessable_content)
      end
      tab = RecurringTemplate::STATUSES.include?(params[:tab]) ? params[:tab] : "active"

      templates = current_user.company.recurring_templates.includes(:category, :account, :created_by).to_a
      grouped   = templates.group_by { |t| [ t.direction, t.status ] }
      counts    = RecurringTemplate::DIRECTIONS.index_with do |d|
        RecurringTemplate::STATUSES.index_with { |s| grouped.fetch([ d, s ], []).size }
      end

      rows = grouped.fetch([ direction, tab ], []).sort_by { |t| tab == "trash" ? t.deleted_at : t.created_at }.reverse
      page, page_size = page_params
      paged = rows.slice((page - 1) * page_size, page_size) || []

      ids       = paged.map(&:id)
      generated = generated_counts(ids)
      deleters  = tab == "trash" ? AuditLog.deleted_by_map(current_user.company, "recurring_template", ids) : {}

      render json: {
        data: paged.map { |t| serialize(t, generated: generated.fetch(t.id, 0), deleted_by: deleters[t.id]) },
        meta: { total: rows.size, page: page, page_size: page_size, counts: counts }
      }
    end

    # GET /api/recurring-templates/:id
    def show
      render json: serialize(@template)
    end

    # POST /api/recurring-templates/preview
    # 儲存時會當場產生的筆數，吃表單當下的週期與月份。只查詢，不寫入。
    # 編輯時帶 template_id，用範本現況加表單的值，和 PATCH 走同一段邏輯。
    def preview
      today = Date.current
      if params[:template_id].present?
        template = current_user.company.recurring_templates.kept.find_by(id: params[:template_id])
        return render json: { error: "not_found" }, status: :not_found if template.nil?

        attrs = params.permit(*SCHEDULE_FIELDS, :category_id)
        return render_invalid(template) unless template.apply_edit(attrs, today: today, preview: true)
        periods = template.generate_on_save ? template.due_periods(today) : []
      else
        template = RecurringTemplate.new(params.permit(*SCHEDULE_FIELDS))
        return render_invalid(template) unless template.preview_valid?
        periods = template.periods_in_range? ? template.due_periods(today) : []
      end

      has_periods = template.periods_in_range?
      template.last_generated_period = periods.last if periods.any?
      next_period = template.next_period if has_periods

      render json: {
        backfill_count:   periods.size,
        backfill_periods: periods,
        has_periods:      has_periods,
        next_period:      next_period,
        next_date:        next_period && template.due_date(next_period).iso8601,
        message:          has_periods ? nil : RecurringTemplate::NO_PERIODS_MESSAGE
      }
    end

    # POST /api/recurring-templates
    # 建立並補齊已過的期數。
    def create
      template = current_user.company.recurring_templates.new(
        template_params.merge(direction: params[:direction], created_by: current_user)
      )

      backfilled = 0
      saved = false
      ActiveRecord::Base.transaction do
        saved = template.save
        next unless saved

        AuditLog.record!(template, action: "create", by: current_user, after: template.audit_snapshot)
        backfilled = RecurringGenerator.call(template, today: Date.current)
      end
      return render_invalid(template) unless saved

      render json: serialize(template).merge(backfilled_count: backfilled), status: :created
    end

    # PATCH /api/recurring-templates/:id
    # 只影響尚未產生的期數。歷史範本回到進行中、改週期時，已過的期數不補，從當期開始；
    # 只改週期日時不補也不跳過。這些情況都在儲存當下產生週期日已過的期數，不等每日檢查；
    # 開始月份改到過去時比照建立補齊。
    def update
      today = Date.current
      backfilled = nil

      ActiveRecord::Base.transaction do
        @template.lock!
        next render_invalid(@template) unless @template.apply_edit(template_params, today: today)

        @template.save!
        audit_update_change!
        backfilled = RecurringGenerator.call(@template, today: today) if @template.generate_on_save
      end
      return if performed?

      render json: serialize(@template).merge(backfilled ? { backfilled_count: backfilled } : {})
    end

    # DELETE /api/recurring-templates/:id
    # 進垃圾桶，任何時候都可以；已產生的紀錄不受影響。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已在垃圾桶，不再寫稽核。
    def destroy
      ActiveRecord::Base.transaction do
        @template.lock!
        next if @template.discarded?

        @template.discard!
        AuditLog.record!(@template, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @template.deleted_at&.iso8601 })
      end
      render json: {}, status: :ok
    end

    # PATCH /api/recurring-templates/:id/restore
    # 類別在垃圾桶或已停用時不可還原。不補垃圾桶期間的期數；當期週期日已過且尚未產生的，立即產生一筆。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已還原，不再寫稽核。
    def restore
      today = Date.current
      backfilled = 0

      ActiveRecord::Base.transaction do
        @template.lock!
        next unless @template.discarded?

        next render_invalid(@template) if @template.category_blocked?

        prev_deleted_at = @template.deleted_at&.iso8601
        @template.restore_from_trash!(today: today)
        AuditLog.record!(@template, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
        backfilled = RecurringGenerator.call(@template, today: today)
      end
      return if performed?

      render json: serialize(@template).merge(backfilled_count: backfilled)
    end

    # DELETE /api/recurring-templates/:id/purge
    # 永久刪除。已產生的紀錄保留，recurring_template_id 清空、recurring_period 保留。
    # audit log 必須在 destroy! 前寫入，否則 target.company 撈不到。
    # 先鎖範本再確認還在垃圾桶，和 restore 互斥：剛被還原的範本不刪，也不會有新紀錄指向它。
    def purge
      ActiveRecord::Base.transaction do
        @template.lock!
        next render json: { error: "not_found" }, status: :not_found unless @template.discarded?

        AuditLog.record!(@template, action: "purge", by: current_user, before: @template.audit_snapshot)
        @template.destroy!
        render json: {}, status: :ok
      end
    end

    # GET /api/recurring-templates/:id/records?page=&per_page=
    # 範本產生的紀錄，依期數新到舊，不含垃圾桶內的紀錄。
    def records
      expense = @template.direction == "expense"
      scope   = (expense ? @template.expenses : @template.incomes).kept.includes(:account)
      page, page_size = page_params
      total   = scope.count
      rows    = scope.order(recurring_period: :desc).limit(page_size).offset((page - 1) * page_size)

      render json: {
        data: rows.map { |r| serialize_record(r, expense: expense) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_template
      @template = current_user.company.recurring_templates.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @template.nil?
    end

    def set_any_template
      @template = current_user.company.recurring_templates.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @template.nil?
    end

    def set_discarded_template
      @template = current_user.company.recurring_templates.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @template.nil?
    end

    def template_params
      params.permit(*EDITABLE_FIELDS)
    end

    def page_params
      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      [ page, [ page_size, MAX_PAGE_SIZE ].min ]
    end

    # 各範本未在垃圾桶的紀錄筆數：{ 範本 id => 筆數 }。
    def generated_counts(ids)
      [ Expense, Income ].each_with_object(Hash.new(0)) do |model, counts|
        model.kept.where(recurring_template_id: ids).group(:recurring_template_id).count
          .each { |id, count| counts[id] += count }
      end
    end

    def audit_update_change!
      diff = @template.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      before, after = AuditLog.update_payload(diff)
      AuditLog.record!(@template, action: "update", by: current_user, before: before, after: after)
    end

    def serialize(t, generated: generated_counts([ t.id ]).fetch(t.id, 0), deleted_by: nil)
      next_period = t.discarded? ? nil : t.next_period
      category    = t.category
      {
        id:            t.id.to_s,
        direction:     t.direction,
        name:          t.name,
        category:      category_ref(category),
        account:       { id: t.account.id.to_s, name: t.account.name },
        document_type: t.document_type,
        tax_rate:      t.tax_rate,
        counterparty:  t.counterparty,
        tax_id:        t.tax_id,
        amount:        t.amount.to_f,
        frequency:     t.frequency,
        day_of_month:  t.day_of_month,
        month_of_year: t.month_of_year,
        start_month:   t.start_month,
        end_month:     t.end_month,
        status:        t.status,
        generated_count:       generated,
        last_generated_period: t.last_generated_period,
        next_period:           next_period,
        next_date:             next_period && t.due_date(next_period).iso8601,
        start_month_locked:    t.start_month_locked?,
        restorable:    !category.discarded? && !category.is_archived,
        deleted_at:    t.deleted_at&.iso8601,
        deleted_by:    person_ref(deleted_by),
        created_by:    person_ref(t.created_by),
        created_at:    t.created_at.iso8601,
        updated_at:    t.updated_at.iso8601
      }
    end

    def serialize_record(r, expense:)
      {
        id:               r.id.to_s,
        kind:             expense ? "expense" : "income",
        recurring_period: r.recurring_period,
        date:             r.date.iso8601,
        amount:           r.amount.to_f,
        status:           expense ? r.payout_status : r.collection_status,
        settled_at:       (expense ? r.paid_at : r.collected_at)&.iso8601,
        invoice_no:       r.invoice_no,
        account:          { id: r.account.id.to_s, name: r.account.name }
      }
    end

    def category_ref(c)
      {
        id: c.id.to_s, name: c.name, account_code: c.account_code,
        is_archived: c.is_archived, deleted_at: c.deleted_at&.iso8601
      }
    end

    def person_ref(user)
      user && { id: user.id.to_s, name: user.name }
    end

    # 驗證錯誤的 type 就是錯誤代碼，一次回第一個錯誤。
    def render_invalid(template)
      error = template.errors.first
      code  = error.type.to_s
      render_error(code, error.message, CONFLICT_CODES.include?(code) ? :conflict : :unprocessable_content)
    end

    def render_error(code, message, status)
      render json: { error: code, message: message }, status: status
    end
  end
end
