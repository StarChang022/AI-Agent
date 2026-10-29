module Api
  # 類別 endpoints。皆要求 JWT 登入，且限定呼叫者所屬 company。
  # kind 區分支出 / 收入；兩種類別可同名、各自獨立排序。預算只綁 expense。
  #
  # 權限分野：¥
  # - index：admin 與 employee 皆可（前台員工新增代墊款需要類別下拉）；
  #   employee 僅能看使用中類別、不帶 usage_count。
  # - 其餘（create / update / archive / unarchive / reorder）：僅 admin。
  class CategoriesController < ApplicationController
    before_action :require_admin, except: :index
    before_action :set_category, only: %i[update archive unarchive]

    # GET /api/categories?kind=expense|income&archived=true&include_usage=true
    # kind 必填。未帶 archived → 回傳該 kind 的未停用類別（新增下拉來源）；
    # archived=true → 只回傳該 kind 已停用類別（admin 專用，CategoriesView「已停用」tab）。
    # include_usage=true → 一併回傳每筆 usage_count（admin 專用，CategoriesView 用；
    # expense kind：加總 expenses + reimbursements 引用筆數；income kind：目前恆為 0）。
    # employee 呼叫時 archived / include_usage 皆強制忽略（固定為「使用中、不含 usage」）。
    def index
      kind = parse_kind(params[:kind])
      return render_error("INVALID_KIND", :unprocessable_content) if kind.nil?

      is_admin   = current_user&.role_admin?
      archived   = is_admin && archived_only?
      with_usage = is_admin && include_usage?

      scope = current_user.company.categories.of_kind(kind)
      scope = archived ? scope.archived : scope.active
      scope = with_usage_count(scope, kind) if with_usage

      render json: scope.map { |c| serialize(c, with_usage: with_usage) }
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
      if existing
        return render json: { error: "DUPLICATE_NAME", category: serialize(existing) }, status: :conflict
      end

      category = current_user.company.categories.create!(
        kind:         kind,
        name:         name,
        account_code: params[:account_code].to_s,
        sort_order:   params[:sort_order].presence || next_sort_order(kind)
      )
      render json: serialize(category), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/categories/:id
    # body: { name?, account_code?, sort_order? }
    # 禁止透過本 endpoint 改 is_archived（走 archive / unarchive）。
    # 已停用類別禁止修改——先 unarchive 才能編輯。
    def update
      return render_error("CATEGORY_ARCHIVED", :conflict) if @category.is_archived

      attrs = {}
      attrs[:name]         = params[:name].to_s.strip       if params.key?(:name)
      attrs[:account_code] = params[:account_code].to_s     if params.key?(:account_code)
      attrs[:sort_order]   = params[:sort_order].to_i       if params.key?(:sort_order)

      if attrs.key?(:name) && attrs[:name].blank?
        return render_error("INVALID_NAME", :unprocessable_content)
      end

      if attrs.key?(:name)
        dup = current_user.company.categories
                          .of_kind(@category.kind)
                          .where("LOWER(name) = ?", attrs[:name].downcase)
                          .where.not(id: @category.id)
                          .first
        return render json: { error: "DUPLICATE_NAME", category: serialize(dup) }, status: :conflict if dup
      end

      @category.update!(attrs)
      render json: serialize(@category)
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

      records = current_user.company.categories.where(id: ids).to_a
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
    # 停用時同步清除：該類別所有基本預算範本 + 當期/未來已設定的 Budget
    # （period_end >= today）。過往期間的 Budget 保留供歷史查閱。
    # 解除停用後不會自動恢復——使用者要重新設定 template 與各期 Budget。
    def archive
      return render_error("ALREADY_ARCHIVED", :conflict) if @category.is_archived

      ActiveRecord::Base.transaction do
        @category.budgets.where("period_end >= ?", Date.current).destroy_all
        @category.budget_templates.destroy_all
        @category.update!(is_archived: true)
      end

      render json: serialize(@category)
    end

    # PATCH /api/categories/:id/unarchive
    def unarchive
      return render_error("NOT_ARCHIVED", :conflict) unless @category.is_archived
      @category.update!(is_archived: false)
      render json: serialize(@category)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_category
      @category = current_user.company.categories.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @category.nil?
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

    # 用相關子查詢加總 Expense + Reimbursement 的引用筆數；income kind 目前恆為 0，
    # 待 incomes 表上線後把這個 scope 擴充掉。
    def with_usage_count(scope, kind)
      case kind
      when "expense"
        scope.select(
          "categories.*",
          "(SELECT COUNT(*) FROM expenses WHERE expenses.category_id = categories.id) " \
          "+ (SELECT COUNT(*) FROM reimbursements WHERE reimbursements.category_id = categories.id) " \
          "AS usage_count"
        )
      else
        scope.select("categories.*", "0 AS usage_count")
      end
    end

    def serialize(category, with_usage: false)
      base = {
        id:           category.id.to_s,
        kind:         category.kind,
        name:         category.name,
        account_code: category.account_code,
        is_archived:  category.is_archived,
        sort_order:   category.sort_order,
        created_at:   category.created_at.iso8601,
        updated_at:   category.updated_at.iso8601
      }
      base[:usage_count] = category.respond_to?(:usage_count) ? category.usage_count.to_i : 0 if with_usage
      base
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
