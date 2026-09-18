module Semaphore::GithubApp
  class Collaborators
    class Worker
      include Sidekiq::Worker
      include Semaphore::GithubApp::UniqueLockManagement

      sidekiq_options :queue => :github_app,
                      :lock => :until_expired,
                      :lock_args_method => ->(args) { [args.first] },
                      :on_conflict => { :client => :log, :server => :reject },
                      :lock_ttl => App.worker_lock_ttl,
                      :retry => App.worker_max_retries,
                      :dead => false

      sidekiq_retry_in do |count, exception, _jobhash|
        Semaphore::GithubApp::RateLimit.retry_delay(count, exception)
      end

      sidekiq_retries_exhausted do |job, exception|
        slug = job["args"].first
        Rails.logger.error("[Repository Collaborators Refresh] #{slug}: Retries exhausted — #{exception.class}: #{exception.message}")
        new.delete_unique_lock([slug])
      end

      def perform(slug, remote_id = nil)
        log(slug, "Start")

        if slug.blank?
          log(slug, "Empty")
          return
        end

        result = Semaphore::GithubApp::Collaborators.refresh(slug, remote_id)

        case result
        when :ok
          log(slug, "Finish")
        when :no_token
          log(slug, "Token not found")
        when :no_repository
          log(slug, "Repository not found on GitHub")
        else
          log(slug, "Unknown result: #{result.inspect}")
        end

        delete_unique_lock([slug])
      rescue LowRateLimitError
        # Keep the lock so Sidekiq retries.
        log(slug, "Low Rate Limit — deferring retry until the bucket resets")
        raise
      end

      private

      def log(slug, message)
        Rails.logger.info("[Repository Collaborators Refresh] #{slug}: #{message}")
      end
    end
  end
end
