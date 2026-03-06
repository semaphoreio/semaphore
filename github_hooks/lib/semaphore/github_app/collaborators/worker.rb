module Semaphore::GithubApp
  class Collaborators
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
          slug = normalize_slug(Array(args).first)
          return [] if slug.blank?

          [slug]
        end

        def retry_delay_seconds(retry_count)
          exponent = [retry_count.to_i, 6].min
          base_delay = RETRY_BASE_SECONDS * (2**exponent)
          bounded_delay = [base_delay, RETRY_MAX_SECONDS].min

          bounded_delay + Kernel.rand(0..RETRY_JITTER_SECONDS)
        end

        def normalize_slug(slug)
          normalized_slug = slug.to_s.strip
          return if normalized_slug.blank?

          normalized_slug.downcase
        end
      end

      def perform(slug, remote_id = nil)
        slug = self.class.normalize_slug(slug)
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
        when :low_rate_limit
          log(slug, "Low Rate Limit")
          raise LowRateLimitError, "GitHub App API rate limit is below threshold for #{slug}"
        else
          log(slug, "Unknown result: #{result.inspect}")
        end
      rescue StandardError => e
        log(slug, "Failed: #{e.class} #{e.message}")
        raise
      end

      private

      def log(slug, message)
        Rails.logger.info("[Repository Collaborators Refresh] #{slug}: #{message}")
      end
    end
  end
end
