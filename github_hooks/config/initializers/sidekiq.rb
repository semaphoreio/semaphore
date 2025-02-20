Sidekiq.configure_server do |config|
  config.average_scheduled_poll_interval = 2
  config.error_handlers << proc { |exception, context_hash| Exceptions.notify(exception, context_hash) }

  config.redis = { :url => App.redis_sidekiq_url, :id => nil, :password => App.redis_sidekiq_password }

  config.on(:startup) do |startup_event|
    Rails.logger.info(startup_event)
    system("touch /tmp/ready") # For Kubernetes readiness probe
  end

  [:quiet, :shutdown].each do |event|
    config.on(event) { Rails.logger.info(event) }
  end
end

Sidekiq.configure_client do |config|
  config.redis = { :url => App.redis_sidekiq_url, :id => nil, :password => App.redis_sidekiq_password }
end
