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

  # Reserved-headroom floor on the GitHub App's shared REST bucket: background
  # collaborator/repository sync steps aside below this so interactive/CI calls
  # keep budget.
  config.collaborators_api_rate_limit = (SemaphoreConfig.collaborators_api_rate_limit || 4000).to_i

  # Jitter window (seconds) a rate-limited sync waits past the bucket reset before
  # retrying, so a fanned-out sweep disperses across the post-reset window instead
  # of stampeding it. Scale up with the number of repositories in the installation.
  config.github_app_rate_limit_defer_spread =
    (SemaphoreConfig.github_app_rate_limit_defer_spread || 1800).to_i

  # Master switch that stops all GitHub App collaborator sync — the automatic
  # webhook path and the collaborator fan-out of a manual org refresh alike.
  # DISABLE_COLLABORATOR_WEBHOOK_SYNC is the deprecated former name, read as an
  # alias so existing operators keep working.
  config.disable_collaborator_sync =
    (SemaphoreConfig.disable_collaborator_sync.presence ||
     SemaphoreConfig.disable_collaborator_webhook_sync.presence ||
     "false") == "true"
  config.use_github_app_to_check_permissions =
    (SemaphoreConfig.use_github_app_to_check_permissions || "false") == "true"
  config.semaphore_edition = (SemaphoreConfig.semaphore_edition || "").downcase

  config.worker_max_retries    = (SemaphoreConfig.worker_max_retries || 10).to_i
  config.worker_lock_ttl       = (SemaphoreConfig.worker_lock_ttl || 86_400).to_i
  config.worker_base_delay     = (SemaphoreConfig.worker_base_delay || 900).to_i
  config.worker_jitter_max     = (SemaphoreConfig.worker_jitter_max || 300).to_i
  config.worker_max_delay      = (SemaphoreConfig.worker_max_delay || 7_200).to_i

  def self.ee?
    config.semaphore_edition == "ee"
  end
end
