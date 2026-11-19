# 讓 controller 具備 JWT 驗證能力。
#
# 用法：
#   class ApplicationController < ActionController::API
#     include Authenticatable
#   end
#
#   class Api::AuthController < ApplicationController
#     skip_before_action :authenticate!, only: %i[register login forgot_password reset_password]
#   end
#
# 在 protected action 內使用 `current_user` 取得已登入 user。
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    token = extract_bearer_token
    return render_unauthorized if token.blank?

    payload = JwtService.decode(token)
    @current_user = User.find_by(id: payload["user_id"])
    # 帳號被停用後，手上的 token 立即失效（前端收到 401 會登出）。
    render_unauthorized if @current_user.nil? || @current_user.status_suspended?
  rescue JWT::DecodeError, JWT::ExpiredSignature
    render_unauthorized
  end

  def current_user
    @current_user
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil if header.blank?
    header.split(" ", 2).last if header.start_with?("Bearer ")
  end

  def render_unauthorized
    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
