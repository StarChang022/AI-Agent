module Api
  # 後台儀表板彙總數字（docs/收入管理規格.md §5、儀表板與報表-規格與實作計畫.md §一）。
  # 全部要求 JWT + role=admin，資料限定當前使用者所屬 company。
  class DashboardController < ApplicationController
    before_action :require_admin

    # GET /api/dashboard/summary
    # 本月收入（incomes.date）、本月支出（expenses.date）、淨額、待收款、待付款
    # （含未結清代墊款）、待簽核。垃圾桶、作廢代墊款不計入。
    def summary
      today       = Date.current
      month_start = today.beginning_of_month
      month_end   = today.end_of_month

      company          = current_user.company
      monthly_incomes  = company.incomes.kept.where(date: month_start..month_end)
      monthly_expenses = company.expenses.kept.where(date: month_start..month_end)

      income_amount  = monthly_incomes.sum(:amount).to_f
      expense_amount = monthly_expenses.sum(:amount).to_f

      pending_in_scope  = company.incomes.kept.uncollected
      pending_out_scope = company.expenses.kept.pending
      in_review_scope   = company.reimbursements.visible.where(status: "in_review")

      render json: {
        month: { start: month_start.iso8601, end: month_end.iso8601 },
        monthly_income:  { amount: income_amount,  count: monthly_incomes.count },
        monthly_expense: { amount: expense_amount, count: monthly_expenses.count },
        monthly_net:     income_amount - expense_amount,
        pending_in: {
          amount: pending_in_scope.sum(:amount).to_f,
          count:  pending_in_scope.count
        },
        pending_out: {
          amount:               pending_out_scope.sum(:amount).to_f,
          count:                pending_out_scope.count,
          reimbursement_amount: pending_out_scope.from_reimbursement.sum(:amount).to_f,
          overdue_count:        pending_out_scope.where("planned_payout_date < ?", today).count
        },
        in_review: {
          amount: in_review_scope.sum(:amount).to_f,
          count:  in_review_scope.count
        }
      }
    end

    # GET /api/dashboard/trend?from=&to=&bucket=day|month
    # 期間內收支趨勢。預設近 12 個月（含本月）、bucket=month。收入依 incomes.date、
    # 支出依 expenses.date；垃圾桶（kept）皆排除。labels 保留空桶，數值補 0 以利前端畫圖。
    def trend
      bucket = params[:bucket].presence || "month"
      return render_error("INVALID_BUCKET", :unprocessable_content) unless %w[day month].include?(bucket)

      today = Date.current
      default_from = (today - 11.months).beginning_of_month
      default_to   = today.end_of_month

      from = parse_date(params[:from]) || default_from
      to   = parse_date(params[:to])   || default_to
      return render_error("INVALID_RANGE", :unprocessable_content) if from > to

      company = current_user.company
      income_map  = aggregate_by_bucket(company.incomes.kept,  bucket, from, to)
      expense_map = aggregate_by_bucket(company.expenses.kept, bucket, from, to)
      labels      = build_labels(bucket, from, to)

      render json: {
        range: { from: from.iso8601, to: to.iso8601, bucket: bucket },
        labels: labels,
        series: {
          income:  labels.map { |l| income_map[l].to_f },
          expense: labels.map { |l| expense_map[l].to_f }
        }
      }
    end

    # GET /api/dashboard/category-breakdown?from=&to=&kind=expense|income
    # 期間內依類別分組的金額加總。預設當月、kind=expense；收入依 incomes.date、
    # 支出依 expenses.date；垃圾桶（kept）排除。slices 依金額新到舊；只回有值的類別。
    def category_breakdown
      kind = params[:kind].presence || "expense"
      return render_error("INVALID_KIND", :unprocessable_content) unless %w[expense income].include?(kind)

      today = Date.current
      from  = parse_date(params[:from]) || today.beginning_of_month
      to    = parse_date(params[:to])   || today.end_of_month
      return render_error("INVALID_RANGE", :unprocessable_content) if from > to

      company = current_user.company
      scope =
        if kind == "income"
          company.incomes.kept
        else
          company.expenses.kept
        end

      totals = scope
        .where(date: from..to)
        .joins(:category)
        .group("categories.id", "categories.name")
        .sum(:amount)

      total   = totals.values.sum.to_f
      slices  = totals.sort_by { |_key, amount| -amount }.map do |(id, name), amount|
        amt = amount.to_f
        {
          category_id:   id.to_s,
          category_name: name,
          amount:        amt,
          pct:           total.zero? ? 0.0 : (amt / total * 100).round(2)
        }
      end

      render json: {
        range: { from: from.iso8601, to: to.iso8601, kind: kind },
        total: total,
        slices: slices
      }
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    # 以 Postgres date_trunc + to_char 一次 GROUP BY 加總。bucket 已在 action 內
    # 過白名單，可直接內插；date 欄位本身是 date 型別，不需 timezone 轉換。
    def aggregate_by_bucket(scope, bucket, from, to)
      fmt = bucket == "day" ? "YYYY-MM-DD" : "YYYY-MM"
      scope
        .where(date: from..to)
        .group(Arel.sql("to_char(date_trunc('#{bucket}', date), '#{fmt}')"))
        .sum(:amount)
    end

    # 產生從 from 到 to 的連續 bucket 標籤（含兩端）；bucket=day 逐日、month 逐月。
    def build_labels(bucket, from, to)
      labels = []
      cursor = bucket == "day" ? from : from.beginning_of_month
      step   = bucket == "day" ? 1.day : 1.month
      format = bucket == "day" ? "%Y-%m-%d" : "%Y-%m"
      while cursor <= to
        labels << cursor.strftime(format)
        cursor += step
      end
      labels
    end

    def parse_date(raw)
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
