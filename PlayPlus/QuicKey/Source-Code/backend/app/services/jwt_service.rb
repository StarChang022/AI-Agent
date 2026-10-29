# 產生 / 驗證 JWT access token。
#
# MVP：HS256 對稱簽章、24 小時 TTL、payload 只帶 user_id。
# secret 優先讀 ENV["JWT_SECRET_BASE"]，未設定則 fallback 到
# Rails.application.secret_key_base（後者已是 128-hex 隨機值、存 master.key）。
# 生產環境務必設 ENV，避免共用 secret_key_base。
class JwtService
  ALGORITHM   = "HS256".freeze
  DEFAULT_TTL = 24.hours

  class << self
    def encode(user_id:, exp: DEFAULT_TTL.from_now)
      payload = {
        user_id: user_id,
        exp:     exp.to_i,
        iat:     Time.current.to_i
      }
      JWT.encode(payload, secret, ALGORITHM)
    end

    # 成功回傳 payload hash（含 "user_id"）；失敗 raise JWT::DecodeError 系列。
    def decode(token)
      JWT.decode(token, secret, true, algorithm: ALGORITHM).first
    end

    private

    def secret
      ENV.fetch("JWT_SECRET_BASE") { Rails.application.secret_key_base }
    end
  end
end
