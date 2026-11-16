module Semaphore::RepoHost::Hooks::Intake
  # Verifies a hook and records its workflow. Raises when the hook should be tried again.
  module Processor
    RetryLater = Class.new(StandardError)

    def self.process(webhook)
      Logman.process("hook-intake", :workflow_id => webhook.workflow_id, :delivery_id => webhook.delivery_id) do |logger|
        project = ::Project.find_by(:id => webhook.project_id)

        if project.nil?
          logger.info("Project Not Found")
          :project_not_found
        else
          verify_and_record(webhook, project, logger)
        end
      end
    end

    def self.verify_and_record(webhook, project, logger)
      verdict = Semaphore::RepoHost::Hooks::Handler.webhook_signature_valid?(
        logger, project.organization_id, project.repository.id, webhook.signed_body, webhook.signature
      )

      case verdict
      when :ok
        record(webhook, project, logger)
      when :retry
        raise RetryLater, "the signature check could not be made"
      else
        logger.info("request-not-verified")
        :not_verified
      end
    end

    def self.record(webhook, project, logger)
      workflow, delivery = Semaphore::RepoHost::Hooks::Recorder.record_verified_hook(
        webhook.workflow_id, webhook.request, project, webhook.received_at
      )

      if workflow.nil?
        logger.info("Request Already Saved")
        return :duplicate
      end

      logger.add(:post_commit_request_id => workflow.id, :project_id => project.id)
      logger.info("Saved Request")
      push(delivery, logger)

      :recorded
    end

    # The delivery is stored, so a job that cannot be pushed now is pushed by the sweeper.
    def self.push(delivery, logger)
      sidekiq_job_id = HookDelivery.push(delivery.workflow_id, delivery.job_id)
      logger.info("Enqueud in Sidekiq", :sidekiq_job_id => sidekiq_job_id)
    rescue RedisClient::Error => e
      Watchman.increment("hooks.intake.enqueue_failed")
      logger.error("Enqueue in Sidekiq failed", :error => e.class.name)
    end
  end
end
