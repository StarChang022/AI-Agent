require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Vstarter
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.time_zone = 'Taipei'

    config.generators do |g|
      # 建立controller時不自動建立 assets & helper
      g.assets false
      g.helper false

      # 自動產生rspec檔案
      g.test_framework :rspec
        # [uncheck]
        # fixtures: true,
        # view_specs: false,
        # helper_specs: false,
        # routing_specs: false,
        # controller_specs: false,
        # request_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    overrides = "#{Rails.root}/app/overrides"
    Rails.autoloaders.main.ignore(overrides)
    config.to_prepare do
      Dir.glob("#{overrides}/**/*_override.rb").each do |override|
        load override
      end
    end

    # Read ActionMailer config from config/mailer.yml
    initializer "action_mailer.set_configs.set_yaml_configs", before: "action_mailer.set_configs" do |app|
      next unless File.exist?(Rails.root.join("config", "mailer.yml"))

      configure = app.config_for("mailer").deep_symbolize_keys
      configure.each do |key, value|
        setter = "#{key}="
        unless app.config.action_mailer.respond_to? setter
          raise "Can't set option `#{key}` to ActionMailer, make sure that options in config/mailer.yml are valid."
        end

        app.config.action_mailer.send(setter, value)
      end
    end

    config.active_storage.variant_processor = :vips

    config.assets.precompile += %w(*.png *.jpg *.jpeg *.gif *.svg *.ttf *.otf)

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
