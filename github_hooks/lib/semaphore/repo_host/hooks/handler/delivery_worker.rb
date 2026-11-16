class Semaphore::RepoHost::Hooks::Handler

  # Runs a stored hook delivery. The job carries only the workflow id; the delivery
  # row holds the attempt counts and names the job that may run it.
  class DeliveryWorker

    include Sidekiq::Worker

    sidekiq_options :queue => :job_pipeline

    # Sidekiq's default backoff; the lease outlasts it and its jitter.
    sidekiq_retry_in do |count, _exception, job|
      delay = (count**4) + 15
      HookDelivery.await_retry(job["args"].first, job["jid"], delay + (10 * (count + 1)))

      delay
    end

    # A resumed approval keeps its claim through transient errors; once Sidekiq
    # stops retrying, free it so a new /sem-approve can claim the workflow.
    sidekiq_retries_exhausted do |job, _exception|
      HookDelivery.finish(job["args"].first, job["jid"])

      workflow = ::Workflow.find_by(:id => job["args"].first)
      Semaphore::RepoHost::Hooks::Handler.release_pr_approval(workflow) if workflow
    end

    def perform(workflow_id)
      self.class.process(workflow_id, jid)
    end

    def self.process(workflow_id, job_id)
      delivery = HookDelivery.claim(workflow_id, job_id)

      if delivery.nil?
        Logman.info("hook-delivery-not-claimed", :workflow_id => workflow_id)
        return
      end

      begin
        # Retry to silence race condition errors
        Retryable.retryable(:tries => 2) do
          Logman.process("processing-in-sidekiq", :workflow_id => workflow_id) do |logger|
            workflow = ::Workflow.find_by(:id => workflow_id)

            if workflow
              Semaphore::RepoHost::Hooks::Handler.run(workflow, logger, :delivery => delivery)
            else
              logger.info("request-not-found")
            end
          end
        end

        HookDelivery.finish(workflow_id, job_id)
      ensure
        HookDelivery.release(workflow_id, job_id)
      end
    end

  end

end
