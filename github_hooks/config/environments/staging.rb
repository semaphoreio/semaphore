Semaphore::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  config.log_level = ENV.fetch("LOG_LEVEL", "info")

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect"

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.public_file_server.enabled = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Compress both stylesheets and JavaScripts
  config.assets.js_compressor = Uglifier.new(:mangle => false, :output => { :comments => :none })
  config.assets.compress = true
  # config.assets.css_compressor = :scss

  # Generate digests for assets URLs
  config.assets.digest = true
  config.action_controller.asset_host = App.asset_host
  config.action_mailer.asset_host = config.action_controller.asset_host

  config.lograge.enabled = true

  config.lograge.custom_options = lambda do |event|
    { :time => event.time }
  end
end
