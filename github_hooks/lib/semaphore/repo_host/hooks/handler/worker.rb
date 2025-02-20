class Semaphore::RepoHost::Hooks::Handler

  class Worker

    include Sidekiq::Worker

    sidekiq_options :queue => :job_pipeline

    def perform(workflow_id, hook_payload = "", signature = "", retries = 0)
      # Retry to silence race condition errors
      Retryable.retryable(:tries => 2) do
        Logman.process("processing-in-sidekiq", :workflow_id => workflow_id) do |logger|
          workflow = ::Workflow.find(workflow_id)

          Semaphore::RepoHost::Hooks::Handler.run(workflow, logger, hook_payload, signature, retries)
        end
      end
    end

  end

end
