module Semaphore::RepoHost::Hooks
  # GitHub hooks reach processing through a durable RabbitMQ queue: the endpoint answers
  # only once the broker has confirmed the hook, and the broker keeps it until a tackle
  # consumer has verified and recorded it.
  module Intake
    EXCHANGE = "github_hooks_exchange".freeze
    ROUTING_KEY = "received_webhook".freeze
    SERVICE = "github_hooks".freeze
    # The queue tackle declares for SERVICE and ROUTING_KEY.
    QUEUE = "#{SERVICE}.#{ROUTING_KEY}".freeze
    # A hook that fails is retried 10 times, 2 minutes apart, then kept in tackle's dead queue.
    RETRY_DELAY = 2.minutes
    RETRY_LIMIT = 10

    def self.enabled?
      App.rabbitmq_hook_intake
    end

    def self.consumer_options(**overrides)
      {
        :url => App.amqp_url,
        :exchange => EXCHANGE,
        :routing_key => ROUTING_KEY,
        :service => SERVICE,
        :retry_delay => RETRY_DELAY.to_i,
        :retry_limit => RETRY_LIMIT
      }.merge(overrides)
    end
  end
end
