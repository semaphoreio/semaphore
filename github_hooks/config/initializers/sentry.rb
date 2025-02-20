Sentry.init do |config|
  if Rails.env.production? || Rails.env.staging?
    config.dsn = ENV["SENTRY_DSN_WITH_SECRET"]
    config.environment = ENV["SENTRY_ENV"] || "production"
    config.enabled_environments = ["prod", "pre-prod", "production"]
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    config.excluded_exceptions += [
      "SignalException",
      "ActiveRecord::ConcurrentMigrationError",
      "GRPC::NotFound"
    ]
  end
end
