module Semaphore::GithubApp
  class Repositories
    class Worker
      include Sidekiq::Worker

      MAX_RETRY_ATTEMPTS = App.github_app_refresh_max_retry_attempts
      RETRY_BASE_SECONDS = App.github_app_refresh_retry_base_seconds
      RETRY_MAX_SECONDS = App.github_app_refresh_retry_max_seconds
      RETRY_JITTER_SECONDS = App.github_app_refresh_retry_jitter_seconds

      class LowRateLimitError < StandardError; end

      sidekiq_options \
        :queue => :github_app,
        :retry => MAX_RETRY_ATTEMPTS,
        :lock => :until_executed,
        :on_conflict => :log,
        :lock_args_method => :lock_args

      sidekiq_retry_in do |retry_count, _exception|
        retry_delay_seconds(retry_count)
      end

      class << self
        def lock_args(args)
          installation_id = Array(args).first
          return [] if installation_id.blank?

          [installation_id.to_i]
        end

        def retry_delay_seconds(retry_count)
          exponent = [retry_count.to_i, 6].min
          base_delay = RETRY_BASE_SECONDS * (2**exponent)
          bounded_delay = [base_delay, RETRY_MAX_SECONDS].min

          bounded_delay + Kernel.rand(0..RETRY_JITTER_SECONDS)
        end
      end

      def perform(installation_id)
        installation_id = installation_id.to_i
        log(installation_id, "Start")

        result = Semaphore::GithubApp::Repositories.refresh(installation_id)

        case result
        when :ok
          log(installation_id, "Finish")
        when :no_token
          log(installation_id, "Token not found")
        when :no_installation
          log(installation_id, "Installation not found")
        when :low_rate_limit
          log(installation_id, "Low Rate Limit")
          raise LowRateLimitError, "GitHub App API rate limit is below threshold for installation #{installation_id}"
        else
          log(installation_id, "Unknown result: #{result.inspect}")
        end
      rescue StandardError => e
        log(installation_id, "Failed: #{e.class} #{e.message}")
        raise
      end

      private

      def log(installation_id, message)
        Rails.logger.info("[Installation Repository Refresh] #{installation_id}: #{message}")
      end
    end
  end
end
