require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Taiwan 時區：影響 Date.current / Time.current / Time.zone.now 等「現在」的判定，
    # 以及 ActiveRecord 讀出來的 timestamp 被包成 Time.zone。DB 一律存 UTC（Rails 預設），
    # 僅進出口做轉換。付款日規則「本月為界」等語意依賴此設定正確。
    config.time_zone = "Asia/Taipei"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # 全 table 用 UUID PK / FK，未來 rails g migration 產生的檔案會自動帶 uuid。
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
