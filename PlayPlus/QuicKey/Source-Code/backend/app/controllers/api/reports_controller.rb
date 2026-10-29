require "axlsx"

module Api
  # 後台報表（docs/收入管理規格.md §4、儀表板與報表-規格與實作計畫.md §二、§三）。
  # 全部要求 JWT + role=admin，資料限定當前使用者所屬 company。
  class ReportsController < ApplicationController
    BUCKET_LABELS = { "month" => "月", "quarter" => "季", "year" => "年" }.freeze

    before_action :require_admin

    # GET /api/reports/profit-loss?from=&to=&bucket=month|quarter|year
    # 損益報表：以開立日 / 費用發生日歸屬（incomes.date / expenses.date）。
    # 垃圾桶、作廢代墊款不計入。預設當年度（本年 1/1 ~ 12/31、bucket=月）。
    # 回每個 bucket 的 income / expense / net / budget / budget_usage_pct 與合計。
    def profit_loss
      bucket = params[:bucket].presence || "month"
      return render_error("INVALID_BUCKET", :unprocessable_content) unless %w[month quarter year].include?(bucket)

      today = Date.current
      default_from = today.beginning_of_year
      default_to   = today.end_of_year

      from = parse_date(params[:from]) || default_from
      to   = parse_date(params[:to])   || default_to
      return render_error("INVALID_RANGE", :unprocessable_content) if from > to

      rows  = build_pl_rows(bucket, from, to)
      total = aggregate_total(rows)

      respond_pl(bucket, from, to, rows, total)
    end

    # GET /api/reports/cashflow?from=&to=&bucket=month|quarter|year
    # 現金流報表：以收款日 / 付款日歸屬（incomes.collected_at / expenses.paid_at）。
    # 待收 / 待付不計入月份數字；另列 pending_in / pending_out 清單（整家公司，不受期間限制）。
    # 垃圾桶、作廢代墊款不計入。預設當年度（本年 1/1 ~ 12/31、bucket=月）。
    def cashflow
      bucket = params[:bucket].presence || "month"
      return render_error("INVALID_BUCKET", :unprocessable_content) unless %w[month quarter year].include?(bucket)

      today = Date.current
      from = parse_date(params[:from]) || today.beginning_of_year
      to   = parse_date(params[:to])   || today.end_of_year
      return render_error("INVALID_RANGE", :unprocessable_content) if from > to

      rows        = build_cf_rows(bucket, from, to)
      total       = aggregate_cf_total(rows)
      pending_in  = pending_in_list
      pending_out = pending_out_list

      respond_cf(bucket, from, to, rows, total, pending_in, pending_out)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    # 依 bucket 切出每個子區間，分別算 income / expense / budget。
    def build_pl_rows(bucket, from, to)
      company     = current_user.company
      income_map  = aggregate_amount_by_bucket(company.incomes.kept,  bucket, from, to)
      expense_map = aggregate_amount_by_bucket(company.expenses.kept, bucket, from, to)
      bucket_ranges(bucket, from, to).map do |label, period_start, period_end|
        income  = income_map[label].to_f
        expense = expense_map[label].to_f
        budget  = budget_amount_for(period_start, period_end)
        {
          label:            label,
          income:           income,
          expense:          expense,
          net:              income - expense,
          budget:           budget,
          budget_usage_pct: usage_pct(expense, budget)
        }
      end
    end

    def aggregate_total(rows)
      income  = rows.sum { |r| r[:income] }
      expense = rows.sum { |r| r[:expense] }
      budget  = rows.sum { |r| r[:budget] }
      {
        income:           income,
        expense:          expense,
        net:              income - expense,
        budget:           budget,
        budget_usage_pct: usage_pct(expense, budget)
      }
    end

    # 以 Postgres date_trunc + to_char 一次 GROUP BY 加總，key 回和 bucket_ranges 相同格式的 label。
    # bucket 已在 action 內過白名單；date_col 由程式內部傳入（不接 params），可安全內插。
    # 損益報表以 :date 歸屬；現金流報表以 :collected_at / :paid_at 歸屬。
    def aggregate_amount_by_bucket(scope, bucket, from, to, date_col: :date)
      fmt = case bucket
            when "month"   then "YYYY-MM"
            when "quarter" then "YYYY-\"Q\"Q"
            when "year"    then "YYYY"
            end
      scope
        .where(date_col => from..to)
        .group(Arel.sql("to_char(date_trunc('#{bucket}', #{date_col}), '#{fmt}')"))
        .sum(:amount)
    end

    # 產生 [[label, period_start, period_end], ...]；label 和 aggregate_amount_by_bucket 對齊。
    def bucket_ranges(bucket, from, to)
      cursor = truncate_to_bucket(bucket, from)
      ranges = []
      while cursor <= to
        period_start = cursor
        period_end   = bucket_end(bucket, cursor)
        ranges << [ format_label(bucket, period_start), period_start, period_end ]
        cursor = period_end + 1
      end
      ranges
    end

    def truncate_to_bucket(bucket, date)
      case bucket
      when "month"   then date.beginning_of_month
      when "quarter" then date.beginning_of_quarter
      when "year"    then date.beginning_of_year
      end
    end

    def bucket_end(bucket, date)
      case bucket
      when "month"   then date.end_of_month
      when "quarter" then date.end_of_quarter
      when "year"    then date.end_of_year
      end
    end

    def format_label(bucket, date)
      case bucket
      when "month"   then date.strftime("%Y-%m")
      when "quarter" then "#{date.year}-Q#{((date.month - 1) / 3) + 1}"
      when "year"    then date.strftime("%Y")
      end
    end

    # 期間內的預算額：
    # - 月預算：若整個 period 落在該月份內 → 全額；否則按 period 與該月交集比例攤分。
    # - 年預算：按 period 與該年交集天數 / 該年總天數攤分（簡化成一致演算法：
    #   皆按日曆天數比例計算，兼顧 bucket=month / quarter / year 三種情境）。
    def budget_amount_for(period_start, period_end)
      budgets = current_user.company.budgets
        .where("period_end >= ? AND period_start <= ?", period_start, period_end)
      budgets.sum do |b|
        overlap_from = [ b.period_start, period_start ].max
        overlap_to   = [ b.period_end,   period_end ].min
        next 0 if overlap_from > overlap_to
        total_days   = (b.period_end - b.period_start).to_i + 1
        overlap_days = (overlap_to - overlap_from).to_i + 1
        (b.amount * overlap_days / total_days).to_f
      end
    end

    def usage_pct(expense, budget)
      return 0.0 if budget.to_f.zero?
      (expense.to_f / budget.to_f * 100).round(2)
    end

    def respond_pl(bucket, from, to, rows, total)
      if params[:format] == "xlsx"
        send_pl_xlsx(bucket, from, to, rows, total)
      else
        render json: {
          range: { from: from.iso8601, to: to.iso8601, bucket: bucket },
          rows:  rows,
          total: total
        }
      end
    end

    def send_pl_xlsx(bucket, from, to, rows, total)
      package = Axlsx::Package.new
      wb      = package.workbook
      wb.add_worksheet(name: "損益報表") do |sheet|
        sheet.add_row [ "期間：#{from.iso8601} ～ #{to.iso8601}（彙總單位：#{BUCKET_LABELS[bucket]}）" ]
        sheet.add_row []
        sheet.add_row [ "期間", "收入", "支出", "淨額", "預算", "預算執行率(%)" ]
        rows.each do |r|
          sheet.add_row [ r[:label], r[:income], r[:expense], r[:net], r[:budget], r[:budget_usage_pct] ]
        end
        sheet.add_row [ "合計", total[:income], total[:expense], total[:net], total[:budget], total[:budget_usage_pct] ]
      end
      send_data package.to_stream.read,
        filename: "profit-loss_#{from.iso8601}_#{to.iso8601}.xlsx",
        type: Mime[:xlsx].to_s,
        disposition: "attachment"
    end

    # 現金流 rows：每個 bucket 的 cash_in / cash_out / net。
    # 已收款的收入依 collected_at、已付款的支出依 paid_at 歸屬；未收/未付不計。
    def build_cf_rows(bucket, from, to)
      company = current_user.company
      cash_in_map  = aggregate_amount_by_bucket(company.incomes.kept.collected, bucket, from, to, date_col: :collected_at)
      cash_out_map = aggregate_amount_by_bucket(company.expenses.kept.paid,    bucket, from, to, date_col: :paid_at)
      bucket_ranges(bucket, from, to).map do |label, _s, _e|
        cash_in  = cash_in_map[label].to_f
        cash_out = cash_out_map[label].to_f
        { label: label, cash_in: cash_in, cash_out: cash_out, net: cash_in - cash_out }
      end
    end

    def aggregate_cf_total(rows)
      cash_in  = rows.sum { |r| r[:cash_in] }
      cash_out = rows.sum { |r| r[:cash_out] }
      { cash_in: cash_in, cash_out: cash_out, net: cash_in - cash_out }
    end

    # 待收款清單（整家公司）：以開立日排序，前端自行判斷逾期。
    def pending_in_list
      current_user.company.incomes.kept.uncollected
        .order(:date, :created_at)
        .pluck(:id, :customer, :amount, :date)
        .map { |id, customer, amount, date| { id: id, customer: customer, amount: amount.to_f, date: date.iso8601 } }
    end

    # 待付款清單（整家公司）：以預計付款日排序（NULL 擺最後），前端自行判斷逾期。
    def pending_out_list
      current_user.company.expenses.kept.pending
        .order(Arel.sql("planned_payout_date ASC NULLS LAST"), :date)
        .pluck(:id, :vendor, :amount, :planned_payout_date)
        .map do |id, vendor, amount, planned|
          { id: id, vendor: vendor, amount: amount.to_f, planned_payout_date: planned&.iso8601 }
        end
    end

    def respond_cf(bucket, from, to, rows, total, pending_in, pending_out)
      if params[:format] == "xlsx"
        send_cf_xlsx(bucket, from, to, rows, total, pending_in, pending_out)
      else
        render json: {
          range:       { from: from.iso8601, to: to.iso8601, bucket: bucket },
          rows:        rows,
          total:       total,
          pending_in:  pending_in,
          pending_out: pending_out
        }
      end
    end

    def send_cf_xlsx(bucket, from, to, rows, total, pending_in, pending_out)
      package = Axlsx::Package.new
      wb      = package.workbook

      wb.add_worksheet(name: "現金流") do |sheet|
        sheet.add_row [ "期間：#{from.iso8601} ～ #{to.iso8601}（彙總單位：#{BUCKET_LABELS[bucket]}）" ]
        sheet.add_row []
        sheet.add_row [ "期間", "收款", "付款", "淨流" ]
        rows.each { |r| sheet.add_row [ r[:label], r[:cash_in], r[:cash_out], r[:net] ] }
        sheet.add_row [ "合計", total[:cash_in], total[:cash_out], total[:net] ]
      end

      wb.add_worksheet(name: "待收款") do |sheet|
        sheet.add_row [ "客戶", "金額", "開立日" ]
        pending_in.each { |r| sheet.add_row [ r[:customer], r[:amount], r[:date] ] }
      end

      wb.add_worksheet(name: "待付款") do |sheet|
        sheet.add_row [ "廠商", "金額", "預計付款日" ]
        pending_out.each { |r| sheet.add_row [ r[:vendor], r[:amount], r[:planned_payout_date] ] }
      end

      send_data package.to_stream.read,
        filename: "cashflow_#{from.iso8601}_#{to.iso8601}.xlsx",
        type: Mime[:xlsx].to_s,
        disposition: "attachment"
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
