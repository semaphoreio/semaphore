require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module Semaphore
  class Application < Rails::Application
    config.load_defaults "7.2"

    config.autoload_paths << "#{root}/lib"

    config.autoloader = :zeitwerk

    # Use dynamic generated error pages instead of ones in public/ folder
    config.exceptions_app = routes

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Enable the asset pipeline
    config.assets.enabled = true
    # Can be set to invalidate the whole cache
    config.assets.version = "1.3"
    # Serving static assets and setting cache headers
    # # which will be used by cloudfront as well
    config.public_file_server.enabled = true
    config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=31536000' }

    if ENV["SEMAPHORE_CACHE_DIR"]
      config.assets.configure do |env|
        env.cache = ActiveSupport::Cache::FileStore.new("#{ENV["SEMAPHORE_CACHE_DIR"]}/assets-cache")
      end
    end

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :credentials, :token, :refresh_token]

    config.action_view.field_error_proc = proc { |html_tag, _instance| %Q(<div class="error">#{html_tag}</div>).html_safe }

    config.active_record.dump_schema_after_migration = false

    # Remove milliseconds from json serialized times to match rails 3 behaviour
    config.active_support.time_precision = 0

    # https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#expiry-in-signed-or-encrypted-cookie-is-now-embedded-in-the-cookies-values
    config.action_dispatch.use_authenticated_cookie_encryption = false

    # https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#purpose-and-expiry-metadata-is-now-embedded-inside-signed-and-encrypted-cookies-for-increased-security
    config.action_dispatch.use_cookies_with_metadata = false

    config.action_dispatch.trusted_proxies = App.trusted_proxies
  end
end
