module Semaphore::GithubApp
  class RepositoryRefresh
    # Background fetch for a targeted refresh of a not-yet-cached repository:
    # looks the repo up on GitHub (the specific-repo endpoint), adds it to the
    # installation cache, and syncs its collaborators. Runs async so the request
    # returns immediately; the caller's claim to the installation is verified in
    # RepositoryRefresh.targeted before this is enqueued.
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
        installation_id, slug = job["args"]
        Rails.logger.error("[Targeted Repository Refresh] #{installation_id}/#{slug}: Retries exhausted — #{exception.class}: #{exception.message}")
        new.delete_unique_lock([installation_id, slug])
      end

      def perform(installation_id, slug)
        log(installation_id, slug, "Start")

        if slug.blank?
          log(installation_id, slug, "Empty slug")
          return
        end

        result = Semaphore::GithubApp::RepositoryRefresh.fetch_and_cache_repository(installation_id, slug)

        case result
        when :ok
          log(installation_id, slug, "Finish")
          delete_unique_lock([installation_id, slug])
        when :no_token
          log(installation_id, slug, "Token not found")
          delete_unique_lock([installation_id, slug])
        when :no_repository
          log(installation_id, slug, "Repository not accessible to the installation")
          delete_unique_lock([installation_id, slug])
        when :low_rate_limit
          log(installation_id, slug, "Low Rate Limit — raising to trigger retry with backoff")
          raise LowRateLimitError, "GitHub App API rate limit too low for installation #{installation_id}"
        else
          log(installation_id, slug, "Unknown result: #{result.inspect}")
          delete_unique_lock([installation_id, slug])
        end
      end

      private

      def log(installation_id, slug, message)
        Rails.logger.info("[Targeted Repository Refresh] #{installation_id}/#{slug}: #{message}")
      end
    end
  end
end
