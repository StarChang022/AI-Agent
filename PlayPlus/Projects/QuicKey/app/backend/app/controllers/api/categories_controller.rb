module Api
  # 類別 endpoints。皆要求 JWT 登入，且限定呼叫者所屬 company。
  # kind 區分支出 / 收入；兩種類別可同名、各自獨立排序。預算只綁 expense。
  #
  # 權限分野：¥
  # - index：admin 與 employee 皆可（前台員工新增代墊款需要類別下拉）；
  #   employee 僅能看使用中類別、不帶 usage_count。
  # - 其餘（create / update / archive / unarchive / reorder 與垃圾桶）：僅 admin。
  # 合約見 docs/dev/recurring-api.md 第 4 節。
  class CategoriesController < ApplicationController
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100
    SYSTEM_BLOCKED_REASON = "這是系統保留類別，資金移轉手續費會使用，不可停用或刪除".freeze
    # 寫入稽核的異動欄位；停用與啟用也歸 update。排序走 reorder，不寫稽核。
    AUDITED_UPDATE_FIELDS = %w[name account_code sort_order is_archived].freeze

    before_action :require_admin, except: :index
    before_action :set_category, only: %i[update archive unarchive destroy]
    before_action :set_discarded_category, only: %i[restore purge]
    before_action :reject_system_category, only: %i[archive destroy purge]

    # GET /api/categories?kind=expense|income&archived=true&include_usage=true
    # kind 必填。未帶 archived → 回傳該 kind 的未停用類別（新增下拉來源）；
    # archived=true → 只回傳該 kind 已停用類別（admin 專用，CategoriesView「已停用」tab）。
    # include_usage=true → 一併回傳引用筆數與可否刪除、停用（admin 專用，CategoriesView 用）。
    # 垃圾桶內的類別一律不回，走 trash。
    # employee 呼叫時 archived / include_usage 皆強制忽略（固定為「使用中、不含 usage」）。
    def index
      kind = parse_kind(params[:kind])
      return render_error("INVALID_KIND", :unprocessable_content) if kind.nil?

      is_admin   = current_user&.role_admin?
      archived   = is_admin && archived_only?
      with_usage = is_admin && include_usage?

      scope = current_user.company.categories.of_kind(kind)
      categories = (archived ? scope.archived : scope.active).to_a

      render json: with_usage ? serialize_with_usage(categories) : categories.map { |c| serialize(c) }
    end

    # GET /api/categories/trash?kind=&page=&per_page=
    # 垃圾桶列表，依刪除時間新到舊。
    def trash
      kind = parse_kind(params[:kind])
      return render_error("INVALID_KIND", :unprocessable_content) if kind.nil?

      scope     = current_user.company.categories.of_kind(kind).discarded.order(deleted_at: :desc)
      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      records  = scope.limit(page_size).offset((page - 1) * page_size).to_a
      deleters = AuditLog.deleted_by_map(current_user.company, "category", records.map(&:id))

      render json: {
        data: serialize_with_usage(records, deleted_by: deleters),
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # POST /api/categories
    # body: { kind, name, account_code?, sort_order? }
    # kind 建立後不可改；重複檢查於同一 (company, kind) 內 case-insensitive。
    def create
      kind = parse_kind(params[:kind])
      return render_error("INVALID_KIND", :unprocessable_content) if kind.nil?

      name = params[:name].to_s.strip
      return render_error("INVALID_NAME", :unprocessable_content) if name.blank?

      existing = current_user.company.categories
                             .of_kind(kind)
                             .where("LOWER(name) = ?", name.downcase)
                             .first
      return render_duplicate_name(existing) if existing

      category = current_user.company.categories.new(
        kind:         kind,
        name:         name,
        account_code: params[:account_code].to_s,
        sort_order:   params[:sort_order].presence || next_sort_order(kind)
      )
      ActiveRecord::Base.transaction do
        category.save!
        AuditLog.record!(category, action: "create", by: current_user, after: category.audit_snapshot)
      end
      render json: serialize(category), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/categories/:id
    # body: { name?, account_code?, sort_order? }
    # 禁止透過本 endpoint 改 is_archived（走 archive / unarchive）。
    # 已停用類別禁止修改——先 unarchive 才能編輯。
    # 鎖定後才確認狀態：同時修改時，第二筆的稽核 before 是第一筆改完的值；期間被停用或刪除則擋下。
    def update
      attrs = {}
      attrs[:name]         = params[:name].to_s.strip       if params.key?(:name)
      attrs[:account_code] = params[:account_code].to_s     if params.key?(:account_code)
      attrs[:sort_order]   = params[:sort_order].to_i       if params.key?(:sort_order)

      ActiveRecord::Base.transaction do
        @category.lock!
        next render_not_found if @category.discarded?
        next render_error("CATEGORY_ARCHIVED", :conflict) if @category.is_archived
        next render_error("INVALID_NAME", :unprocessable_content) if attrs.key?(:name) && attrs[:name].blank?

        if attrs.key?(:name)
          dup = current_user.company.categories
                            .of_kind(@category.kind)
                            .where("LOWER(name) = ?", attrs[:name].downcase)
                            .where.not(id: @category.id)
                            .first
          next render_duplicate_name(dup) if dup
        end

        @category.update!(attrs)
        audit_update_change!
        render json: serialize(@category)
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/categories/reorder
    # body: { ids: ["uuid1", "uuid2", ...] }
    # 批次重設 sort_order：ids 內第 i 個對應 sort_order=i，未傳入的 category
    # 保持原 sort_order 不動。ids 內的類別必須全部同一 kind，否則整批退回；
    # 回傳僅該 kind 的使用中類別。前端拖曳支出 / 收入分頁時各自呼叫一次。
    def reorder
      ids = params[:ids]
      unless ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.present? }
        return render_error("INVALID_IDS", :unprocessable_content)
      end

      records = current_user.company.categories.kept.where(id: ids).to_a
      if records.size != ids.uniq.size
        return render_error("INVALID_IDS", :unprocessable_content)
      end
      if records.any?(&:is_archived)
        return render_error("CATEGORY_ARCHIVED", :conflict)
      end
      kinds = records.map(&:kind).uniq
      return render_error("MIXED_KINDS", :unprocessable_content) if kinds.size > 1
      kind = kinds.first

      by_id = records.index_by { |c| c.id.to_s }
      now = Time.current
      ActiveRecord::Base.transaction do
        ids.each_with_index do |id, i|
          c = by_id[id.to_s]
          next if c.sort_order == i
          c.update_columns(sort_order: i, updated_at: now)
        end
      end

      render json: current_user.company.categories.of_kind(kind).active.map { |c| serialize(c) }
    end

    # PATCH /api/categories/:id/archive
    # 停用時同步清除基本預算與當期、未來的預算（Category#clear_current_budgets!）。
    # 進行中範本使用的類別不可停用。先鎖類別再查範本，和範本存檔時的鎖互斥。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已停用，不再寫稽核；期間被刪除回 404。
    def archive
      ActiveRecord::Base.transaction do
        @category.lock!
        next render_not_found if @category.discarded?
        next render_error("ALREADY_ARCHIVED", :conflict) if @category.is_archived
        next if render_in_use_by_template

        @category.clear_current_budgets!(by: current_user)
        @category.update!(is_archived: true)
        audit_update_change!
        render json: serialize(@category)
      end
    end

    # PATCH /api/categories/:id/unarchive
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已啟用，不再寫稽核；期間被刪除回 404。
    def unarchive
      ActiveRecord::Base.transaction do
        @category.lock!
        next render_not_found if @category.discarded?
        next render_error("NOT_ARCHIVED", :conflict) unless @category.is_archived

        @category.update!(is_archived: false)
        audit_update_change!
        render json: serialize(@category)
      end
    end

    # DELETE /api/categories/:id
    # 進垃圾桶，比照停用清預算，還原後不恢復；is_archived 不動。進行中範本使用的類別不可刪除。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已在垃圾桶，不再寫稽核。
    def destroy
      ActiveRecord::Base.transaction do
        @category.lock!
        next render json: {}, status: :ok if @category.discarded?
        next if render_in_use_by_template

        @category.clear_current_budgets!(by: current_user)
        @category.discard!
        AuditLog.record!(@category, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @category.deleted_at&.iso8601 })
        render json: {}, status: :ok
      end
    end

    # PATCH /api/categories/:id/restore
    # 回到原本的狀態，原本停用的仍為停用。垃圾桶內的名稱仍佔用，還原不會撞名。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已還原，不再寫稽核。
    def restore
      ActiveRecord::Base.transaction do
        @category.lock!
        next unless @category.discarded?

        prev_deleted_at = @category.deleted_at&.iso8601
        @category.restore_from_trash!
        AuditLog.record!(@category, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
      end
      render json: serialize(@category)
    end

    # DELETE /api/categories/:id/purge
    # 永久刪除。有任何引用時拒絕；檢查通過後才有紀錄引用，外鍵會擋下，一樣回 409。
    # audit log 必須在 destroy! 前寫入，否則 target.company 撈不到。
    # 鎖定後重新確認還在垃圾桶，剛被還原的類別不刪。
    def purge
      ActiveRecord::Base.transaction do
        @category.lock!
        next render json: { error: "not_found" }, status: :not_found unless @category.discarded?
        next if render_in_use

        AuditLog.record!(@category, action: "purge", by: current_user, before: @category.audit_snapshot)
        @category.destroy!
        render json: {}, status: :ok
      end
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      render_in_use
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    # 對 AUDITED_UPDATE_FIELDS 做 saved_changes diff，有變更才寫 log。需在存檔的交易內呼叫。
    def audit_update_change!
      diff = @category.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?

      before, after = AuditLog.update_payload(diff)
      AuditLog.record!(@category, action: "update", by: current_user, before: before, after: after)
    end

    def set_category
      @category = current_user.company.categories.kept.find_by(id: params[:id])
      render_not_found if @category.nil?
    end

    def render_not_found
      render json: { error: "not_found" }, status: :not_found
    end

    def set_discarded_category
      @category = current_user.company.categories.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @category.nil?
    end

    def reject_system_category
      return unless @category.system?
      render json: { error: "CATEGORY_SYSTEM_RESERVED", message: SYSTEM_BLOCKED_REASON }, status: :conflict
    end

    def archived_only?
      params[:archived].to_s == "true"
    end

    def include_usage?
      params[:include_usage].to_s == "true"
    end

    # 僅接受白名單值；格式錯誤或空字串回 nil（呼叫端轉成 400）。
    def parse_kind(raw)
      v = raw.to_s
      Category::KINDS.include?(v) ? v : nil
    end

    def next_sort_order(kind)
      (current_user.company.categories.of_kind(kind).maximum(:sort_order) || -1) + 1
    end

    # 同名類別已存在時 render 409。垃圾桶內的類別也算，請使用者去還原或永久刪除。
    def render_duplicate_name(existing)
      message = existing.discarded? ?
        "垃圾桶內已有同名類別，請還原或永久刪除後再試" : "已有同名類別，請換一個名稱"
      render json: { error: "DUPLICATE_NAME", message: message, category: serialize(existing) }, status: :conflict
    end

    # 有進行中範本使用時 render 409 並回 true。
    def render_in_use_by_template
      templates = @category.active_templates
      return false if templates.empty?

      render json: {
        error:     "CATEGORY_IN_USE_BY_TEMPLATE",
        message:   template_blocked_reason(templates.size),
        templates: templates.map { |t| { id: t.id.to_s, name: t.name } }
      }, status: :conflict
      true
    end

    # 仍被引用時 render 409 並回 true。
    def render_in_use
      counts = @category.usage_counts
      return false if counts.values.all?(&:zero?)

      render json: {
        error:      "CATEGORY_IN_USE",
        message:    "此類別已有 #{Category.describe_usage(counts)}使用（含垃圾桶內的紀錄），不能永久刪除",
        references: counts
      }, status: :conflict
      true
    end

    def template_blocked_reason(count)
      "有 #{count} 筆進行中的固定收支範本使用此類別，不可停用或刪除"
    end

    def serialize(category)
      {
        id:           category.id.to_s,
        kind:         category.kind,
        name:         category.name,
        account_code: category.account_code,
        is_archived:  category.is_archived,
        sort_order:   category.sort_order,
        system_key:   category.system_key,
        deleted_at:   category.deleted_at&.iso8601,
        created_at:   category.created_at.iso8601,
        updated_at:   category.updated_at.iso8601
      }
    end

    # 帶引用筆數與可否刪除、停用的形狀；一次算好，避免每筆都查。
    def serialize_with_usage(categories, deleted_by: nil)
      ids       = categories.map(&:id)
      counts    = Category.usage_counts(ids)
      templates = Category.active_templates(ids)

      categories.map do |c|
        active_count = templates.fetch(c.id, []).size
        blocked_reason = SYSTEM_BLOCKED_REASON if c.system?
        blocked_reason ||= template_blocked_reason(active_count) if active_count.positive?
        usage = {
          usage_count:           counts[c.id].values.sum,
          references:            counts[c.id],
          active_template_count: active_count,
          deletable:             blocked_reason.nil?,
          archivable:            blocked_reason.nil?,
          purgeable:             !c.system? && counts[c.id].values.all?(&:zero?),
          blocked_reason:        blocked_reason
        }
        usage[:deleted_by] = person_ref(deleted_by[c.id]) if deleted_by
        serialize(c).merge(usage)
      end
    end

    def person_ref(user)
      user && { id: user.id.to_s, name: user.name }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
