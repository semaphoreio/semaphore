module Semaphore::GithubApp
  module UniqueLockManagement
    def delete_unique_lock(lock_args)
      SidekiqUniqueJobs::Digests.new.delete_by_digest(unique_lock_digest(lock_args))
    rescue StandardError => e
      Rails.logger.warn("[#{self.class}] Failed to release unique lock for #{lock_args.first}: #{e.message}")
    end

    # True when a job with these lock args is already enqueued. Fails open to
    # false — a slipped duplicate is rejected by the workers' on_conflict.
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
