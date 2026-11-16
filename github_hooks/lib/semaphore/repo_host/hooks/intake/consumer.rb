module Semaphore::RepoHost::Hooks::Intake
  # Takes hooks off the queue with tackle, which acknowledges a hook once `handle` returns
  # and moves it to its delay queue when `handle` raises. A consumer that dies leaves the
  # hook with the broker; its workflow id makes a second delivery of a recorded hook a no-op.
  class Consumer
    def initialize(threads: (ENV["HOOKS_INTAKE_THREADS"].presence || 5).to_i, logger: Logger.new($stdout, :level => Logger::WARN))
      @threads = threads
      @logger = logger
    end

    # Tackle takes one hook at a time per connection, so each thread holds its own.
    def run
      Logman.info("hook-intake-started", :threads => @threads)

      Array.new(@threads) do
        Thread.new do
          Thread.current.abort_on_exception = true
          consume
        end
      end.each(&:join)
    end

    def consume
      Tackle.consume(Semaphore::RepoHost::Hooks::Intake.consumer_options(:logger => @logger)) { |message| handle(message) }
    end

    def handle(message)
      webhook = Webhook.from_message(message)
      ActiveRecord::Base.connection_pool.with_connection { Processor.process(webhook) }
    rescue StandardError => e
      Watchman.increment("hooks.intake.failed")
      Logman.info("hook-intake-failed", :workflow_id => webhook&.workflow_id, :error => e.class.name)
      raise
    end
  end
end
