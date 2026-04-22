module Semaphore::GithubApp
  module UniqueLockManagement
    def delete_unique_lock(lock_args)
      item = { "class" => self.class.to_s, "queue" => "github_app", "lock_args" => lock_args,
               "lock_prefix" => SidekiqUniqueJobs.config.lock_prefix }
      digest = SidekiqUniqueJobs::LockDigest.new(item).lock_digest
      SidekiqUniqueJobs::Digests.new.delete_by_digest(digest)
    rescue StandardError => e
      Rails.logger.warn("[#{self.class}] Failed to release unique lock for #{lock_args.first}: #{e.message}")
    end
  end
end
