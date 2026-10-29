# Be sure to restart your server when you modify this file.
#
# Cross-Origin Resource Sharing (CORS) 設定：讓 Vite dev server（Vue 前端）
# 能打後端 API。正式站部署時把 origins 改為前端網域（例：https://app.quickey.com）
# 或改由 ENV 變數注入。

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose:  [ "Authorization" ],
      credentials: false
  end
end
