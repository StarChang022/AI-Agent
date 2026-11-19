# Quickey 專屬 runtime 設定。可用 ENV 覆寫（12-factor）。

Rails.application.configure do
  # 前端 base URL — password reset link 用。dev 預設 Vite dev server。
  config.frontend_base_url = ENV.fetch("FRONTEND_BASE_URL", "http://localhost:5173")
end
