module Semaphore::GithubApp
  class RepositoryRefresh
    # Async fetch of an uncached repository for a targeted refresh: caches it and
    # syncs its collaborators. Authorization is verified in RepositoryRefresh.targeted
    # before this is enqueued.
    class Worker
      include Sidekiq::Worker
      include Semaphore::GithubApp::UniqueLockManagement

      # Transient failures worth retrying (GitHub 5xx, network, DB timeouts);
      # everything else (e.g. a revoked-token Unauthorized) finishes terminally.
      RETRYABLE_ERRORS = [
        RepoHost::RemoteException::RepoHostIssue,
        Octokit::ServerError,
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        ActiveRecord::StatementInvalid
      ].freeze

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
        installation_id, slug = job["args"]
        Rails.logger.error("[Targeted Repository Refresh] #{installation_id}/#{slug}: Retries exhausted — #{exception.class}: #{exception.message}")
        new.delete_unique_lock([installation_id, slug])
      end

      def perform(installation_id, slug)
        log(installation_id, slug, "Start")

        if slug.blank?
          log(installation_id, slug, "Empty slug")
          delete_unique_lock([installation_id, slug])
          return
        end

        result = Semaphore::GithubApp::RepositoryRefresh.fetch_and_cache_repository(installation_id, slug)

        case result
        when :ok
          log(installation_id, slug, "Finish")
        when :no_token
          log(installation_id, slug, "Token not found")
        when :no_repository
          log(installation_id, slug, "Repository not accessible to the installation")
        when :low_rate_limit
          log(installation_id, slug, "Low Rate Limit — raising to trigger retry with backoff")
          raise LowRateLimitError, "GitHub App API rate limit too low for installation #{installation_id}"
        else
          log(installation_id, slug, "Unknown result: #{result.inspect}")
        end

        delete_unique_lock([installation_id, slug])
      rescue LowRateLimitError
        # Retryable: keep the lock and let Sidekiq retry with backoff.
        raise
      rescue *RETRYABLE_ERRORS => e
        # Transient: keep the lock and re-raise so Sidekiq retries with backoff
        # (bounded by worker_max_retries; the lock is freed on exhaustion).
        log(installation_id, slug, "Transient error — retrying with backoff: #{e.class}: #{e.message}")
        raise
      rescue StandardError => e
        # Anything else is permanent (e.g. a revoked-token Unauthorized): release the
        # lock and finish, so a permanent failure doesn't burn the whole retry budget.
        log(installation_id, slug, "Terminal error — #{e.class}: #{e.message}")
        delete_unique_lock([installation_id, slug])
      end

      private

      def log(installation_id, slug, message)
        Rails.logger.info("[Targeted Repository Refresh] #{installation_id}/#{slug}: #{message}")
      end
    end
  end
end
