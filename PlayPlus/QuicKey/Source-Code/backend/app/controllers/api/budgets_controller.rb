module Api
  # 類別預算 endpoints。全部要求 JWT + role=admin，並限定於呼叫者所屬 company。
  # amount = 0 由呼叫者改走 DELETE（依 frontend/src/api/budgets.ts CreateBudgetRequest JSDoc）。
  class BudgetsController < ApplicationController
    before_action :require_admin
    before_action :set_budget, only: %i[update destroy]

    # GET /api/budgets?category_id=&cycle=&period_start=
    def index
      scope = current_user.company.budgets
      scope = scope.where(category_id:  params[:category_id])  if params[:category_id].present?
      scope = scope.where(cycle:        params[:cycle])        if params[:cycle].present?
      scope = scope.where(period_start: params[:period_start]) if params[:period_start].present?

      render json: scope.order(:period_start, :category_id).map { |b| serialize(b) }
    end

    # POST /api/budgets
    # body: { category_id, cycle, amount, period_start, period_end }
    def create
      amount = parse_amount(params[:amount])
      return render_amount_zero_hint if amount == 0
      return render_error("INVALID_AMOUNT", :unprocessable_content) if amount.nil? || amount < 0

      category = current_user.company.categories.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?

      budget = current_user.company.budgets.new(
        category:     category,
        cycle:        params[:cycle],
        amount:       amount,
        period_start: params[:period_start],
        period_end:   params[:period_end]
      )

      if budget.save
        render json: serialize(budget), status: :created
      else
        render_budget_errors(budget)
      end
    end

    # PATCH /api/budgets/:id
    # body: { amount }
    def update
      amount = parse_amount(params[:amount])
      return render_amount_zero_hint if amount == 0
      return render_error("INVALID_AMOUNT", :unprocessable_content) if amount.nil? || amount < 0

      if @budget.update(amount: amount)
        render json: serialize(@budget)
      else
        render_budget_errors(@budget)
      end
    end

    # DELETE /api/budgets/:id
    def destroy
      @budget.destroy!
      render json: {}, status: :ok
    end

    # GET /api/budgets/utilization?period_start=&period_end=
    # 期間內各使用中支出類別的實際支出加總，給前端算執行率。
    # - 條件：expenses.kept + date 落於 [period_start, period_end]（字串比對；YYYY-MM-DD）
    # - source（general / reimbursement）與 payout_status（pending / paid）皆計入
    # - 回所有使用中支出類別，當期無支出的 actual=0
    # - 注意：歸屬到已停用（archived）類別的 expenses 不會出現在回應中——本 endpoint
    #   只代表「使用中類別」的當期支出。若之後 Dashboard 要算公司總支出，請另外
    #   開獨立 endpoint，不要直接 sum 這份陣列。
    #
    # 回傳 [{ category_id, category_name, actual }, ...]（照類別 sort_order）
    def utilization
      period_start = params[:period_start]
      period_end   = params[:period_end]
      if period_start.blank? || period_end.blank?
        return render_error("PERIOD_REQUIRED", :unprocessable_content)
      end

      sums = current_user.company.expenses.kept
        .where("date >= ? AND date <= ?", period_start, period_end)
        .group(:category_id)
        .sum(:amount)

      rows = current_user.company.categories.of_kind("expense").active.map do |cat|
        {
          category_id:   cat.id.to_s,
          category_name: cat.name,
          actual:        (sums[cat.id] || 0).to_f
        }
      end

      render json: rows
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_budget
      @budget = current_user.company.budgets.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @budget.nil?
    end

    def parse_amount(raw)
      return nil if raw.nil?
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def render_amount_zero_hint
      render json: { error: "AMOUNT_ZERO_USE_DELETE" }, status: :bad_request
    end

    def render_budget_errors(budget)
      if budget.errors[:category_id].any? { |m| m.include?("taken") }
        return render json: { error: "DUPLICATE_PERIOD" }, status: :conflict
      end
      if budget.errors[:period_start].any? { |m| m.include?("cycle") }
        return render json: { error: "PERIOD_MISMATCH_CYCLE" }, status: :unprocessable_content
      end
      render json: validation_error(budget), status: :unprocessable_content
    end

    def serialize(budget)
      {
        id:           budget.id.to_s,
        category_id:  budget.category_id.to_s,
        cycle:        budget.cycle,
        amount:       budget.amount.to_f,
        period_start: budget.period_start.iso8601,
        period_end:   budget.period_end.iso8601,
        created_at:   budget.created_at.iso8601,
        updated_at:   budget.updated_at.iso8601
      }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
