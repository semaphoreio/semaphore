class Semaphore::RepoHost::Hooks::Handler

  class Worker

    include Sidekiq::Worker

    sidekiq_options :queue => :job_pipeline

    # A resumed approval keeps its claim through transient errors; once Sidekiq
    # stops retrying, free it so a new /sem-approve can claim the workflow.
    sidekiq_retries_exhausted do |job, _exception|
      workflow = ::Workflow.find_by(:id => job["args"].first)
      Semaphore::RepoHost::Hooks::Handler.release_pr_approval(workflow) if workflow
    end

    def perform(workflow_id, hook_payload = "", signature = "", retries = 0, stale_attempts = 0) # rubocop:disable Metrics/ParameterLists
      # Retry to silence race condition errors
      Retryable.retryable(:tries => 2) do
        Logman.process("processing-in-sidekiq", :workflow_id => workflow_id) do |logger|
          workflow = ::Workflow.find(workflow_id)

          Semaphore::RepoHost::Hooks::Handler.run(workflow, logger, hook_payload, signature, retries, stale_attempts)
        end
      end
    end

  end

end
