# frozen_string_literal: true

# GitHub results shared by all hook workers, so projects on one repository do
# not repeat the same requests. Fails open: a Redis error reads as a miss.
class Semaphore::RepoHost::Hooks::GithubCache
  KEY_PREFIX = "github_hooks:v1"
  TIMEOUT = 0.2
  POOL_SIZE = 20
  POOL_MUTEX = Mutex.new
  # Errors are counted on every call but logged at most this often per process.
  ERROR_LOG_INTERVAL = 60

  RELEASE_LOCK = <<~LUA
    if redis.call("GET", KEYS[1]) == ARGV[1] then
      return redis.call("DEL", KEYS[1])
    end
    return 0
  LUA

  class << self
    def enabled?
      App.github_shared_cache_enabled
    end

    def read(key)
      return unless enabled?

      value = call("GET", namespaced(key))
      value && JSON.parse(value)
    rescue StandardError => e
      failed("read", e)
    end

    def write(key, value, ttl:, only_new: false)
      return false unless enabled?

      args = ["SET", namespaced(key), JSON.generate(value), "EX", ttl.to_i]
      args << "NX" if only_new
      call(*args) == "OK"
    rescue StandardError => e
      failed("write", e)
      false
    end

    # Returns a token to pass to unlock, or nil when the lock is held elsewhere.
    def lock(key, ttl:)
      return unless enabled?

      token = SecureRandom.hex(16)
      call("SET", namespaced(key), token, "EX", ttl.to_i, "NX") == "OK" ? token : nil
    rescue StandardError => e
      failed("lock", e)
    end

    def unlock(key, token)
      call("EVAL", RELEASE_LOCK, 1, namespaced(key), token)
    rescue StandardError => e
      failed("unlock", e)
    end

    def exists?(key)
      return false unless enabled?

      call("EXISTS", namespaced(key)).to_i.positive?
    rescue StandardError => e
      failed("exists", e)
      false
    end

    private

    def call(*args)
      pool.call(*args)
    end

    def pool
      @pool || POOL_MUTEX.synchronize do
        @pool ||= RedisClient.config(
          :url => App.redis_sidekiq_url,
          :password => App.redis_sidekiq_password,
          :connect_timeout => TIMEOUT,
          :read_timeout => TIMEOUT,
          :write_timeout => TIMEOUT
        ).new_pool(:size => POOL_SIZE, :timeout => TIMEOUT)
      end
    end

    def namespaced(key)
      "#{KEY_PREFIX}:#{key}"
    end

    def failed(operation, error)
      Watchman.increment("github_hooks.shared_cache.error", :tags => [operation])

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if @error_logged_at.nil? || now - @error_logged_at >= ERROR_LOG_INTERVAL
        @error_logged_at = now
        Rails.logger.warn("[GithubCache] #{operation} failed: #{error.class}")
      end
      nil
    end
  end
end
