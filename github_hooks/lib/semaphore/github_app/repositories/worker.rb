module Semaphore::GithubApp
  class Repositories
    class Worker
      include Sidekiq::Worker

      sidekiq_options :queue => :github_app,
                      :lock => :until_expired,
                      :on_conflict => { :client => :log, :server => :reject },
                      :lock_ttl => App.worker_lock_ttl,
                      :retry => App.worker_max_retries

      sidekiq_retry_in do |count, _exception, _jobhash|
        delay = App.worker_base_delay * (2**count)
        jitter = rand(0..App.worker_jitter_max)

        delay + jitter
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
      end

      private

      def log(installation_id, message)
        Rails.logger.info("[Installation Repository Refresh] #{installation_id}: #{message}")
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
