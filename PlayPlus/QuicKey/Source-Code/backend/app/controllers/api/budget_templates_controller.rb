module Api
  # 基本預算範本 endpoints。全部要求 JWT + role=admin。
  # 編輯 template 不會影響任何 Budget；套用（apply）才把 template 值鏡射到指定期間。
  class BudgetTemplatesController < ApplicationController
    before_action :require_admin

    # GET /api/budget-templates?cycle=month|year
    def index
      scope = current_user.company.budget_templates
      scope = scope.where(cycle: params[:cycle]) if params[:cycle].present?

      render json: scope.order(:category_id).map { |t| serialize(t) }
    end

    # PUT /api/budget-templates
    # body: { category_id, cycle, amount }
    # amount = 0 → 刪除既有 template（若存在），回 200 空 body。
    def upsert
      amount = parse_amount(params[:amount])
      return render_error("INVALID_AMOUNT", :unprocessable_content) if amount.nil? || amount < 0

      category = current_user.company.categories.find_by(id: params[:category_id])
      return render_error("CATEGORY_NOT_FOUND", :unprocessable_content) if category.nil?

      cycle = params[:cycle]
      return render_error("INVALID_CYCLE", :unprocessable_content) unless BudgetTemplate::CYCLES.include?(cycle)

      existing = current_user.company.budget_templates.find_by(category_id: category.id, cycle: cycle)

      if amount == 0
        existing&.destroy!
        return render json: {}, status: :ok
      end

      if existing
        existing.update!(amount: amount)
        render json: serialize(existing)
      else
        template = current_user.company.budget_templates.create!(
          category: category, cycle: cycle, amount: amount
        )
        render json: serialize(template), status: :created
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # DELETE /api/budget-templates/:id
    def destroy
      template = current_user.company.budget_templates.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if template.nil?
      template.destroy!
      render json: {}, status: :ok
    end

    # POST /api/budget-templates/apply
    # body: { cycle, period_start, period_end }
    # 對所有使用中類別執行 upsert：template.amount > 0 → 覆寫該期間 Budget；
    # 無 template → 刪除該期間 Budget（= 「取消預算」語意，對齊 Decision 14）。
    def apply
      cycle = params[:cycle]
      return render_error("INVALID_CYCLE", :unprocessable_content) unless Budget::CYCLES.include?(cycle)

      period_start = safe_parse_date(params[:period_start])
      period_end   = safe_parse_date(params[:period_end])
      return render_error("INVALID_PERIOD", :unprocessable_content) if period_start.nil? || period_end.nil?

      unless period_aligns_with_cycle?(cycle, period_start, period_end)
        return render_error("PERIOD_MISMATCH_CYCLE", :unprocessable_content)
      end

      applied = 0
      skipped = 0

      ActiveRecord::Base.transaction do
        templates_by_cat = current_user.company.budget_templates
                                       .where(cycle: cycle)
                                       .index_by(&:category_id)

        current_user.company.categories.active.find_each do |category|
          template = templates_by_cat[category.id]
          existing = current_user.company.budgets.find_by(
            category_id: category.id, cycle: cycle, period_start: period_start
          )

          if template.nil? || template.amount.to_f == 0
            if existing
              existing.destroy!
              applied += 1
            else
              skipped += 1
            end
            next
          end

          if existing
            existing.update!(amount: template.amount) unless existing.amount == template.amount
          else
            current_user.company.budgets.create!(
              category:     category,
              cycle:        cycle,
              amount:       template.amount,
              period_start: period_start,
              period_end:   period_end
            )
          end
          applied += 1
        end
      end

      render json: { applied_count: applied, skipped_count: skipped }, status: :ok
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def parse_amount(raw)
      return nil if raw.nil?
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def safe_parse_date(raw)
      return nil if raw.blank?
      Date.iso8601(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def period_aligns_with_cycle?(cycle, period_start, period_end)
      case cycle
      when "month"
        period_start.day == 1 && period_end == period_start.end_of_month
      when "year"
        period_start.month == 1 && period_start.day == 1 && period_end == period_start.end_of_year
      end
    end

    def serialize(template)
      {
        id:          template.id.to_s,
        category_id: template.category_id.to_s,
        cycle:       template.cycle,
        amount:      template.amount.to_f,
        created_at:  template.created_at.iso8601,
        updated_at:  template.updated_at.iso8601
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
