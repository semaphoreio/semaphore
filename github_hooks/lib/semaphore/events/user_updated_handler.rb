module Semaphore::Events
  #
  # Handles `user_updated` events published by Guard on the `user_exchange`
  # exchange with routing key `updated`.
  #
  # The only state this service holds that depends on the user's GitHub
  # nickname is `github_app_collaborators.c_name`, which mirrors the
  # collaborator's GitHub login keyed by the GitHub numeric UID (`c_id`).
  # When a user renames their GitHub account, the OAuth-self-refresh path in
  # Guard updates `repo_host_accounts.login` and publishes this event so we can
  # keep `c_name` in sync.
  #
  # The handler is idempotent: if no rows are stale, this is a cheap no-op.
  #
  class UserUpdatedHandler
    def self.call(user_id)
      Watchman.benchmark("github_hooks.user_updated_consumer.duration") do
        new(user_id).call
      end
    end

    def initialize(user_id)
      @user_id = user_id
    end

    def call
      rha = RepoHostAccount.github.find_by(:user_id => @user_id)

      if rha.nil?
        Logman.info("[UserUpdatedHandler] No github RHA for user_id=#{@user_id} - skipping")
        return 0
      end

      if rha.github_uid.blank? || rha.login.blank?
        Logman.info(
          "[UserUpdatedHandler] Incomplete RHA for user_id=#{@user_id} " \
          "uid=#{rha.github_uid.inspect} login=#{rha.login.inspect} - skipping"
        )
        return 0
      end

      stale = GithubAppCollaborator
                .where(:c_id => rha.github_uid)
                .where.not(:c_name => rha.login)

      rows_updated = stale.update_all(:c_name => rha.login)

      if rows_updated.positive?
        Logman.info(
          "[UserUpdatedHandler] user_id=#{@user_id} uid=#{rha.github_uid} " \
          "new_login=#{rha.login} rows_updated=#{rows_updated}"
        )
      end

      Watchman.submit(
        "github_hooks.user_updated_consumer.rows_updated",
        rows_updated,
        :gauge
      )

      rows_updated
    end
  end
end
