module Semaphore::GithubApp
  class Repositories
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
        installation_id = job["args"].first
        Rails.logger.error("[Installation Repository Refresh] #{installation_id}: Retries exhausted — #{exception.class}: #{exception.message}")
        new.delete_unique_lock([installation_id])
      end

      def perform(installation_id, sync_collaborators = true) # rubocop:disable Style/OptionalBooleanParameter
        log(installation_id, "Start")

        result = Semaphore::GithubApp::Repositories.refresh(installation_id, :sync_collaborators => sync_collaborators)

        case result
        when :ok
          log(installation_id, "Finish")
        when :no_token
          log(installation_id, "Token not found")
        when :no_installation
          log(installation_id, "Installation not found")
        else
          log(installation_id, "Unknown result: #{result.inspect}")
        end

        delete_unique_lock([installation_id])
      rescue LowRateLimitError
        # Keep the lock so Sidekiq retries.
        log(installation_id, "Low Rate Limit — deferring retry until the bucket resets")
        raise
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
