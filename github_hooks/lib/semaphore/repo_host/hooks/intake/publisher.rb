module Semaphore::RepoHost::Hooks::Intake
  # Publishes hooks to the tackle consumer's exchange. Tackle.publish has no publisher
  # confirms, so this keeps one confirmed channel per process; publishing is serialized,
  # because a confirm wait covers everything outstanding on the channel.
  class Publisher
    Error = Class.new(StandardError)

    CONFIRM_TIMEOUT = 3.seconds

    @mutex = Mutex.new

    class << self
      # Returns once the broker has stored every webhook in the intake queue; raises Error otherwise.
      def publish(webhooks)
        @mutex.synchronize { publish_confirmed(webhooks) }
      end

      def disconnect
        @mutex.synchronize { close }
      end

      private

      def publish_confirmed(webhooks)
        exchange = open_exchange
        raise Error, "the broker is blocking publishers" if @session.blocked?

        @returned.clear
        webhooks.each do |webhook|
          exchange.publish(webhook.to_message, :routing_key => ROUTING_KEY, :persistent => true, :mandatory => true,
                                               :message_id => webhook.workflow_id)
        end

        raise Error, "the broker did not confirm every hook" unless @channel.wait_for_confirms
        raise Error, "the broker could not route every hook" if @returned.any?
      rescue Error
        close
        raise
      rescue StandardError => e
        close
        raise Error, "publishing failed: #{e.class.name}"
      end

      def open_exchange
        forget_connection if @pid != Process.pid
        return @exchange if @channel&.open?

        close
        @pid = Process.pid
        @session = Bunny.new(App.amqp_url, :automatically_recover => false,
                                           :continuation_timeout => CONFIRM_TIMEOUT.in_milliseconds.to_i,
                                           :connection_timeout => CONFIRM_TIMEOUT.to_i)
        @session.start

        # Tackle declares the consumer's queues, so hooks accepted before a consumer first starts wait in them.
        options = Semaphore::RepoHost::Hooks::Intake.consumer_options(:connection => @session, :logger => Logger.new(nil))
        Tackle::Consumer.new(Tackle::Consumer::Params.new(options))

        @returned = []
        @channel = @session.create_channel
        @channel.confirm_select
        @exchange = @channel.direct(EXCHANGE, :durable => true)
        @exchange.on_return { |_info, properties, _body| @returned << properties.message_id }

        @exchange
      end

      def close
        @session&.close
      rescue StandardError
        nil
      ensure
        forget_connection
      end

      # A connection inherited from the parent process is the parent's to close.
      def forget_connection
        @session = nil
        @channel = nil
        @exchange = nil
      end
    end
  end
end
