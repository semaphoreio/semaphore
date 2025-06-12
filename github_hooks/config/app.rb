require "semaphore_config"

class App < Configurable # :nodoc:
  # Settings in config/app/* take precedence over those specified here.
  config.base_domain             = SemaphoreConfig.base_domain || raise("Base domain must be set")
  config.amqp_url                = SemaphoreConfig.amqp_url
  config.watchman_host           = SemaphoreConfig.metrics_host || SemaphoreConfig.watchman_host || "0.0.0.0"
  config.watchman_port           = (SemaphoreConfig.metrics_port || SemaphoreConfig.watchman_port || 8125).to_i
  config.watchman_prefix         = SemaphoreConfig.metrics_prefix || ["front", SemaphoreConfig.metrics_namespace || "dev"].join(".")
  config.watchman_do_filter      = SemaphoreConfig.limit_metrics == "true"
  config.redis_sidekiq_url       = SemaphoreConfig.redis_sidekiq_url || "redis://localhost:6379"
  config.redis_sidekiq_password  = SemaphoreConfig.redis_sidekiq_password
  config.redis_job_logs_url      = SemaphoreConfig.redis_job_logs_url || "redis://localhost:6379"
  config.rbac_internal_url       = SemaphoreConfig.internal_api_url_rbac
  config.plumber_internal_url    = SemaphoreConfig.internal_api_url_plumber
  config.repository_hub_url      = SemaphoreConfig.internal_api_url_repository
  config.hooks_api_url           = SemaphoreConfig.internal_api_url_hooks
  config.instance_config_url     = SemaphoreConfig.internal_api_url_instance_config
  config.encryptor_url           = SemaphoreConfig.encryptor_url
  config.license_checker_url     = SemaphoreConfig.license_checker_url || "license-checker:50051"
  config.enforce_whitelist       = SemaphoreConfig.enforce_whitelist == "true"
  config.trusted_proxies         = SemaphoreConfig.load_balancer_ip.to_s.split(",").map(&:strip).select(&:present?).compact
  config.trused_hosts = [
    IPAddr.new("0.0.0.0/0"),           # All IPv4 addresses, used for healthchecks.
    ".#{SemaphoreConfig.base_domain}"  # All subdomains within base domain.
  ]
  config.always_filter_skip_ci = (SemaphoreConfig.always_filter_skip_ci || "false") == "true"
  config.collaborators_api_rate_limit = (SemaphoreConfig.collaborators_api_rate_limit || 4000).to_i
  config.semaphore_edition = (SemaphoreConfig.semaphore_edition || "").downcase

  def self.ee?
    config.semaphore_edition == "ee"
  end
end
