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

      sidekiq_retry_in do |count, _exception, _jobhash|
        delay = App.worker_base_delay * (2**count)
        jitter = rand(0..App.worker_jitter_max)

        [delay + jitter, App.worker_max_delay].min
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
          delete_unique_lock([slug])
        when :no_token
          log(slug, "Token not found")
          delete_unique_lock([slug])
        when :no_repository
          log(slug, "Repository not found on GitHub")
          delete_unique_lock([slug])
        when :low_rate_limit
          log(slug, "Low Rate Limit — raising to trigger retry with backoff")
          raise LowRateLimitError, "GitHub App API rate limit too low for #{slug}"
        else
          log(slug, "Unknown result: #{result.inspect}")
          delete_unique_lock([slug])
        end
      end

      private

      def log(slug, message)
        Rails.logger.info("[Repository Collaborators Refresh] #{slug}: #{message}")
      end
    end
  end
end
