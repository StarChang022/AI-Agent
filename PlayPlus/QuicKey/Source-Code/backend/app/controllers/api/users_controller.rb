module Api
  # 公司內人員管理 endpoints。
  #
  # 權限：全部需 JWT。
  #   - index / update(id) / set_status / reset_password → admin only
  #   - update_me → 任何已登入使用者（改自己姓名）
  #
  # 不處理憑證生命週期（登入 / 登出 / 自己改密碼 / 忘記密碼）——那些留在 AuthController。
  # 本 controller 把 user 當資源在管理：列表、改欄位、停用、admin 代為重設密碼。
  #
  # 已知限制：JWT 為 stateless，無 token_version 欄位，故 set_status 停用與
  # reset_password 都「無法立即」踢掉目標既有 session——對方要等 token 自然過期
  # 或下次重整才會被強制重新登入。若未來要立即生效，可在 users 表加
  # token_version 欄位，Authenticatable 驗 payload 內的版本號。
  class UsersController < ApplicationController
    before_action :require_admin, only: %i[index update set_status reset_password]
    before_action :set_user, only: %i[update set_status reset_password]

    # GET /api/users?status=active|suspended|all
    # 預設回所有狀態（含 suspended），讓前端 UsersView 的「使用中 / 停用」tab 自己切。
    def index
      scope = current_user.company.users
      scope = scope.where(status: params[:status]) if %w[active suspended invited].include?(params[:status].to_s)

      render json: scope.order(created_at: :asc).map { |u| serialize(u) }
    end

    # PATCH /api/users/me
    # body: { name }
    # 任何已登入使用者改自己的姓名。Email / role / status / password 不走這條。
    def update_me
      name = params[:name].to_s.strip
      return render_error("INVALID_NAME", :unprocessable_content) if name.blank?

      current_user.update!(name: name)
      render json: serialize(current_user)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/users/me/onboarding
    # body: { completed: true | false }
    # 任何已登入使用者標記自己是否已完成新手導覽；completed=true 寫入當下時間，
    # completed=false 清為 nil（供「重跑導覽」入口使用）。
    def update_onboarding
      completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
      return render_error("INVALID_COMPLETED", :unprocessable_content) if completed.nil?

      current_user.update!(onboarding_completed_at: completed ? Time.current : nil)
      render json: serialize(current_user)
    end

    # PATCH /api/users/:id
    # body: { name }
    # Admin 改公司內其他人員的姓名。role 目前前端 Dialog 禁用，故本 endpoint 不處理 role。
    # 本人改自己走 /users/me；若 id 指向自己回 USE_SELF_ENDPOINT。
    def update
      return render_error("USE_SELF_ENDPOINT", :unprocessable_content) if @user.id == current_user.id

      name = params[:name].to_s.strip
      return render_error("INVALID_NAME", :unprocessable_content) if name.blank?

      @user.update!(name: name)
      render json: serialize(@user)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/users/:id/status
    # body: { status: 'active' | 'suspended' }
    # Admin 停用 / 重啟同公司人員。禁止對自己操作（防自殘）。
    def set_status
      return render_error("CANNOT_TARGET_SELF", :unprocessable_content) if @user.id == current_user.id

      new_status = params[:status].to_s
      unless %w[active suspended].include?(new_status)
        return render_error("INVALID_STATUS", :unprocessable_content)
      end

      @user.update!(status: new_status)
      render json: serialize(@user)
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # PATCH /api/users/:id/password
    # body: { new_password }
    # Admin 代為重設同公司人員的密碼，不需舊密碼。本人改自己走 /auth/password/change。
    def reset_password
      return render_error("USE_SELF_ENDPOINT", :unprocessable_content) if @user.id == current_user.id

      new_password = params[:new_password].to_s
      if new_password.length < 8
        return render_error("WEAK_PASSWORD", :unprocessable_content)
      end

      @user.password = new_password
      if @user.save
        head :no_content
      else
        render json: validation_error(@user), status: :unprocessable_content
      end
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_user
      @user = current_user.company.users.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @user.nil?
    end

    def serialize(user)
      {
        id:            user.id.to_s,
        email:         user.email,
        name:          user.name,
        role:          user.role,
        status:        user.status,
        company_id:    user.company_id.to_s,
        created_at:    user.created_at.iso8601,
        last_login_at: user.last_login_at&.iso8601,
        onboarding_completed_at: user.onboarding_completed_at&.iso8601
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
