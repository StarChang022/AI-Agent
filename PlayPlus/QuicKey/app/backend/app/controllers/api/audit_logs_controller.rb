module Api
  # 稽核日誌查詢 endpoints。塞 log 由各業務 controller 自己做；本 controller 只讀，
  # 不提供修改、刪除。皆僅 admin，且限定呼叫者所屬 company。
  #
  # 兩個使用處（見 project_audit-log-ui）：
  # - index / show：後台稽核日誌頁的列表與單筆
  # - history：支出 / 收入 / 代墊款等詳情抽屜 inline 顯示該筆歷程
  # 合約見 docs/dev/recurring-api.md 第 6 節。
  class AuditLogsController < ApplicationController
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100
    MAX_PAGE          = 100_000

    # 列表不載入整份 before / after（可能含憑證內容），來源在資料庫取好：after 沒有時改讀 before。
    SUMMARY_COLUMNS = [
      "audit_logs.id", "audit_logs.company_id", "audit_logs.target_type", "audit_logs.target_id",
      "audit_logs.action", "audit_logs.actor_user_id", "audit_logs.created_at",
      "COALESCE(audit_logs.after->>'via', audit_logs.before->>'via') AS via"
    ].freeze

    before_action :require_admin

    # GET /api/audit-logs?target_type=&action=&actor_id=&date_from=&date_to=&page=&per_page=
    # 稽核日誌頁列表。條件可組合，全部選填。日期以操作時間為準，依台北時間整天計、兩端含當日。
    def index
      target_type = params[:target_type].presence&.to_s
      # params[:action] 固定是 Rails 的控制器動作名，query 帶的 action 要從這裡取。
      action      = request.query_parameters["action"].presence&.to_s
      if target_type && !AuditLog::TARGET_TYPES.include?(target_type)
        return render_invalid("INVALID_TARGET_TYPE", "對象類型不正確，請重新選擇")
      end
      if action && !AuditLog::ACTIONS.include?(action)
        return render_invalid("INVALID_ACTION", "動作不正確，請重新選擇")
      end

      date_from = parse_date(params[:date_from])
      date_to   = parse_date(params[:date_to])
      return render_invalid("INVALID_DATE", "日期格式不正確，請重新選擇") if date_from == :invalid || date_to == :invalid

      scope = current_user.company.audit_logs
      scope = scope.where(target_type: target_type)            if target_type
      scope = scope.where(action: action)                      if action
      scope = scope.where(actor_user_id: params[:actor_id])    if params[:actor_id].present?
      scope = scope.where(created_at: date_from.beginning_of_day..) if date_from
      scope = scope.where(created_at: ...date_to.next_day.beginning_of_day) if date_to

      # 先轉字串：傳陣列時當成沒帶。頁碼設上限，避免超大數字讓資料庫報錯。
      page      = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
      page_size = params[:per_page].to_s.to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      logs = scope.select(*SUMMARY_COLUMNS).includes(:actor).order(created_at: :desc, id: :desc)
                  .limit(page_size).offset((page - 1) * page_size).to_a
      labels = AuditLogTargetLabels.new(current_user.company).call(logs)

      render json: {
        data: logs.map { |l| serialize_summary(l, labels) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # GET /api/audit-logs/history?target_type=expense|income|reimbursement&target_id=uuid
    # 詳情抽屜的歷程。兩個 query 皆必填；回傳該 target 在呼叫者公司的全部歷程，依時間新到舊。
    def history
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

    # GET /api/audit-logs/:id
    def show
      log = current_user.company.audit_logs.select(*SUMMARY_COLUMNS, "audit_logs.before", "audit_logs.after")
                         .includes(:actor).find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if log.nil?

      labels = AuditLogTargetLabels.new(current_user.company).call([ log ])
      render json: serialize_summary(log, labels).merge(before: log.before, after: log.after)
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end

    def render_invalid(code, message)
      render json: { error: code, message: message }, status: :unprocessable_content
    end

    # 沒帶回 nil、格式錯回 :invalid。
    def parse_date(raw)
      return nil if raw.blank?

      Date.iso8601(raw.to_s)
    rescue ArgumentError
      :invalid
    end

    def display_name(user)
      user&.name.presence || user&.email
    end

    def serialize(log)
      {
        id:         log.id,
        action:     log.action,
        actor_name: display_name(log.actor),
        before:     log.before,
        after:      log.after,
        created_at: log.created_at.iso8601
      }
    end

    def serialize_summary(log, labels)
      {
        id:             log.id,
        created_at:     log.created_at.iso8601,
        actor_name:     display_name(log.actor),
        target_type:    log.target_type,
        target_id:      log.target_id,
        target_label:   labels[[ log.target_type, log.target_id ]],
        action:         log.action,
        via:            log.via
      }
    end
  end
end
