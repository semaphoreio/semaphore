module Semaphore::GithubApp
  class Collaborators
    class Worker
      include Sidekiq::Worker

      sidekiq_options :queue => :github_app,
                      :lock => :until_expired,
                      :lock_args_method => ->(args) { [args.first] },
                      :on_conflict => { :client => :log, :server => :reject },
                      :lock_ttl => App.worker_lock_ttl,
                      :retry => App.worker_max_retries

      sidekiq_retry_in do |count, _exception, _jobhash|
        delay = App.worker_base_delay * (2**count)
        jitter = rand(0..App.worker_jitter_max)

        [delay + jitter, App.worker_max_delay].min
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

      def delete_unique_lock(lock_args)
        item = { "class" => self.class.to_s, "queue" => "github_app", "lock_args" => lock_args,
                 "lock_prefix" => SidekiqUniqueJobs.config.lock_prefix }
        digest = SidekiqUniqueJobs::LockDigest.new(item).lock_digest
        SidekiqUniqueJobs::Digests.new.delete_by_digest(digest)
      rescue StandardError => e
        log(lock_args.first, "Failed to release unique lock: #{e.message}")
      end
    end
  end
end
