module Semaphore::GithubApp
  # Shared GitHub App REST rate-limit budgeting for the background sync workers.
  #
  # A reserved-headroom floor, and a retry schedule that defers a throttled job
  # until the bucket resets (plus wide jitter) rather than a fixed exponential
  # backoff whose retries re-converge and refire together.
  module RateLimit
    module_function

    # Below this many remaining core-bucket calls, background App work steps aside
    # so interactive/CI calls sharing the bucket keep their headroom.
    def floor
      App.collaborators_api_rate_limit
    end

    # Whether the client is under the reserved floor. Decided on remaining alone,
    # so a missing reset time still throttles.
    def exceeded?(client)
      client.rate_limit_remaining < floor
    end

    # Raise to defer the current job when under the floor, carrying the reset time
    # (nil if GitHub didn't report one) so the retry can wait for budget. The reset
    # is read only once the floor trips; /rate_limit reads don't spend core quota.
    def guard!(client)
      return unless exceeded?(client)

      raise LowRateLimitError.new("GitHub App REST rate limit below reserved floor", :resets_at => client.rate_limit_resets_at)
    end

    # Sidekiq retry delay. A throttled job waits until the bucket resets, then
    # disperses across the jitter window; any other failure keeps the capped
    # exponential backoff.
    def retry_delay(count, exception)
      return defer_delay(exception.resets_at) if exception.is_a?(LowRateLimitError)

      jitter = rand(0..App.worker_jitter_max)
      [App.worker_base_delay * (2**count) + jitter, App.worker_max_delay].min
    end

    # Seconds until the bucket resets (never negative) plus jitter across the
    # configured spread. Falls back to jitter alone when the reset time is unknown
    # or already past.
    def defer_delay(resets_at, now: Time.now)
      seconds_until_reset = resets_at ? [resets_at.to_i - now.to_i, 0].max : 0
      seconds_until_reset + rand(0..App.github_app_rate_limit_defer_spread)
    end
  end
end
