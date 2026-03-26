require "sidekiq-unique-jobs"

Sidekiq.configure_server do |config|
  config.average_scheduled_poll_interval = 2
  config.error_handlers << proc { |exception, context_hash| Exceptions.notify(exception, context_hash) }

  config.redis = { :url => App.redis_sidekiq_url, :id => nil, :password => App.redis_sidekiq_password }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  SidekiqUniqueJobs::Server.configure(config)

  config.on(:startup) do |startup_event|
    Rails.logger.info(startup_event)
    system("touch /tmp/ready") # For Kubernetes readiness probe
  end

  config.on(:quiet) { Rails.logger.info(:quiet) }

  config.on(:shutdown) do
    Rails.logger.info(:shutdown)

    # Release unique locks held by jobs that were in-flight on THIS process only.
    # Without this, pushed-back jobs would be rejected by the server middleware
    # (on_conflict: { server: :reject }) and discarded (dead: false), leaving the
    # slug/installation locked out until the lock TTL expires.
    identity = begin
      config[:identity] || config.identity
    rescue StandardError
      nil
    end
    if identity
      Sidekiq::Workers.new.each do |process_id, _thread_id, work|
        next unless process_id == identity

        item = work["payload"]
        next unless item.is_a?(Hash) && item["lock_digest"]

        SidekiqUniqueJobs::Digests.new.delete_by_digest(item["lock_digest"])
        Rails.logger.info("[SidekiqUniqueJobs] Released lock for in-flight job #{item["class"]} (#{item["lock_digest"]}) on shutdown")
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { :url => App.redis_sidekiq_url, :id => nil, :password => App.redis_sidekiq_password }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end
