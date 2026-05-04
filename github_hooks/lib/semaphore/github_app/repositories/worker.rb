module Semaphore::GithubApp
  class Repositories
    class Worker
      include Sidekiq::Worker
      include Semaphore::GithubApp::UniqueLockManagement

      sidekiq_options :queue => :github_app,
                      :lock => :until_expired,
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
        installation_id = job["args"].first
        Rails.logger.error("[Installation Repository Refresh] #{installation_id}: Retries exhausted — #{exception.class}: #{exception.message}")
        new.delete_unique_lock([installation_id])
      end

      def perform(installation_id)
        log(installation_id, "Start")

        result = Semaphore::GithubApp::Repositories.refresh(installation_id)

        case result
        when :ok
          log(installation_id, "Finish")
          delete_unique_lock([installation_id])
        when :no_token
          log(installation_id, "Token not found")
          delete_unique_lock([installation_id])
        when :no_installation
          log(installation_id, "Installation not found")
          delete_unique_lock([installation_id])
        when :low_rate_limit
          log(installation_id, "Low Rate Limit — raising to trigger retry with backoff")
          raise LowRateLimitError, "GitHub App API rate limit too low for installation #{installation_id}"
        else
          log(installation_id, "Unknown result: #{result.inspect}")
          delete_unique_lock([installation_id])
        end
      rescue Semaphore::GithubApp::Repositories::IncompleteRepositoryListError => e
        log(installation_id, "Incomplete repository list — raising to trigger retry with backoff: #{e.message}")
        raise
      end

      private

      def log(installation_id, message)
        Rails.logger.info("[Installation Repository Refresh] #{installation_id}: #{message}")
      end
    end
  end
end
