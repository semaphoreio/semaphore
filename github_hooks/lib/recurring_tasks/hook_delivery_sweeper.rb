module RecurringTasks
  # Pushes the job again for hook deliveries whose job was lost, for example when
  # the worker running it was killed or Redis dropped it.
  class HookDeliverySweeper
    include Sidekiq::Worker

    sidekiq_options :queue => :job_pipeline, :retry => false

    def perform
      HookDelivery.sweep
    end
  end
end
