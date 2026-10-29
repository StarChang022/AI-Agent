module Api
  # 稽核日誌查詢 endpoint。塞 log 由各業務 controller 自己做；本 controller 只讀。
  #
  # UI 定位（見 project_audit-log-ui）：不做獨立後台頁，只在支出 / 收入 / 代墊款
  # 詳情抽屜 inline 顯示該筆歷程。前端一次請求一筆 target 的 logs。
  class AuditLogsController < ApplicationController
    before_action :require_admin

    # GET /api/audit_logs?target_type=expense|income|reimbursement&target_id=uuid
    # 兩個 query 皆必填；回傳該 target 在呼叫者公司的全部歷程，依時間新到舊。
    def index
      target_type = params[:target_type].to_s
      target_id   = params[:target_id].to_s
      return render_error("INVALID_TARGET_TYPE", :unprocessable_content) unless AuditLog::TARGET_TYPES.include?(target_type)
      return render_error("TARGET_ID_REQUIRED",  :unprocessable_content) if target_id.blank?

      logs = current_user.company.audit_logs
                         .where(target_type: target_type, target_id: target_id)
                         .includes(:actor)
                         .order(created_at: :desc)

      render json: logs.map { |l| serialize(l) }
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end

    def serialize(log)
      {
        id:         log.id,
        action:     log.action,
        actor_name: log.actor&.name.presence || log.actor&.email,
        before:     log.before,
        after:      log.after,
        created_at: log.created_at.iso8601
      }
    end
  end
end
