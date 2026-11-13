module Api
  # 公司付款日設定（GET / PATCH），僅管理員可操作。
  # PATCH 不會更動任何已登錄支出（含代墊款）的 planned_payout_date；
  # 新規則只套用在之後新登錄 / 核准的支出。寫入分兩步：
  #   1. company.payout_day 更新
  #   2. 若值真的變動，寫一筆 PayoutDayChangeLog
  # 兩步放在同一 transaction，任一失敗整組 rollback。
  class PayoutScheduleController < ApplicationController
    before_action :require_admin

    # GET /api/payout-schedule
    def show
      render json: serialize(current_user.company.payout_day)
    end

    # PATCH /api/payout-schedule   body: { day: 1-31 | null }
    def update
      new_day = parse_day(params[:day])
      return render_error("INVALID_DAY", :unprocessable_content) if new_day == :invalid

      company = current_user.company
      old_day = company.payout_day

      ActiveRecord::Base.transaction do
        company.update!(payout_day: new_day)
        if old_day != new_day
          company.payout_day_change_logs.create!(
            changed_by: current_user,
            changed_at: Time.current,
            from_day:   old_day,
            to_day:     new_day
          )
        end
      end

      render json: serialize(company.payout_day)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    # 接受整數 1–31 或 nil / 空字串（= 關閉自動付款批次）。
    # 其他輸入（非整數、超出範圍）回 :invalid 讓呼叫端轉 422。
    def parse_day(raw)
      return nil if raw.nil? || raw == ""
      v = Integer(raw.to_s, 10)
      return :invalid unless v.between?(1, 31)
      v
    rescue ArgumentError, TypeError
      :invalid
    end

    def serialize(day)
      { day: day }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
