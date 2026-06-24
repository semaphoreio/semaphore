module Semaphore::GithubApp
  module UniqueLockManagement
    def delete_unique_lock(lock_args)
      SidekiqUniqueJobs::Digests.new.delete_by_digest(unique_lock_digest(lock_args))
    rescue StandardError => e
      Rails.logger.warn("[#{self.class}] Failed to release unique lock for #{lock_args.first}: #{e.message}")
    end

    # The digest key is the primary existence marker SidekiqUniqueJobs' own
    # queue script uses to reject duplicates, so it covers until_expired locks.
    # Fails open: a duplicate enqueue attempt is silently dropped by the
    # workers' on_conflict client: :log setting, so a false negative is benign.
    def unique_lock_exists?(lock_args)
      digest = unique_lock_digest(lock_args)
      Sidekiq.redis { |conn| conn.call("EXISTS", digest).to_i.positive? }
    rescue StandardError => e
      Rails.logger.warn("[#{self.class}] Failed to check unique lock for #{lock_args.first}: #{e.message}")
      false
    end

    private

    def unique_lock_digest(lock_args)
      item = { "class" => self.class.to_s, "queue" => "github_app", "lock_args" => lock_args,
               "lock_prefix" => SidekiqUniqueJobs.config.lock_prefix }
      SidekiqUniqueJobs::LockDigest.new(item).lock_digest
    end
  end
end
