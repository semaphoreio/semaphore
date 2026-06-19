module Semaphore::GithubApp
  # Manual re-sync of the GitHub App repository/collaborator cache. Reuses the
  # webhook Sidekiq workers, so their unique locks and rate-limit backoff apply.
  class RepositoryRefresh
    Result = Struct.new(:state, :message)

    def self.full(user_id)
      installation_ids = GithubAppCollaborator.where(:c_id => github_uid_for(user_id)).distinct.pluck(:installation_id)
      installations = GithubAppInstallation.where(:installation_id => installation_ids, :suspended_at => nil)

      if installations.empty?
        return Result.new(:failed, "No GitHub App repositories to refresh. Install the GitHub App first.")
      end

      free = installations.reject do |installation|
        Repositories::Worker.new.unique_lock_exists?([installation.installation_id])
      end

      if free.empty?
        return Result.new(:already_running, "A repository sync is already running. Results will appear shortly.")
      end

      free.each { |installation| refresh_installation(installation) }

      Result.new(:started, "Repository sync started. This can take a few minutes.")
    end

    def self.targeted(user_id, repository_slug)
      slug = GithubAppInstallation.normalize_slug(repository_slug)
      return Result.new(:failed, "Use the owner/repository format.") unless slug

      # Identical opaque result whether the installation is missing or the caller
      # simply has no claim to it, so this endpoint cannot be used to enumerate
      # the repositories/installations of other organizations.
      no_access = Result.new(:failed, "The GitHub App has no access to #{slug}. Grant access on GitHub first.")

      github_uid = github_uid_for(user_id)
      return no_access unless github_uid

      # Already listed for this user means they already have (push) access, so
      # there is nothing to fetch. This is also the path most exposed to repeated
      # manual refreshes, so short-circuiting it drops the unthrottled,
      # synchronous GitHub collaborator re-sync entirely.
      return Result.new(:done, "Repository #{slug} is already in your list.") if listed_for?(github_uid, slug)

      installation = GithubAppInstallation.find_for_repository(slug)

      if installation
        return no_access unless user_collaborates_in?(github_uid, installation)

        refresh_cached_repository(installation, slug)
      else
        installation = GithubAppInstallation.find_for_organization(slug.split("/").first)
        return no_access unless installation && user_collaborates_in?(github_uid, installation)

        refresh_owner_installation(installation, slug)
      end
    end

    # Re-sync the installation's repository list. Repositories.refresh enqueues a
    # collaborator sync for any repo it discovers as newly added, so a blanket
    # per-repo fan-out here would only re-sync already-known repos.
    def self.refresh_installation(installation)
      Repositories::Worker.perform_async(installation.installation_id)
    end
    private_class_method :refresh_installation

    # Refresh collaborators with the stored slug/remote_id, not the user-typed
    # slug — GithubAppCollaborator rows must keep the API-provided casing.
    def self.refresh_cached_repository(installation, slug)
      canonical = GithubAppInstallation.canonical_slug(slug)
      repository = installation.installation_repositories.where("LOWER(slug) = ?", canonical).first

      return Result.new(:failed, "Repository #{slug} is no longer available. Try again.") if repository.nil?

      case Collaborators.refresh(repository.slug, repository.remote_id)
      when :ok
        Result.new(:done, "Repository #{repository.slug} refreshed.")
      when :no_token
        Result.new(:failed, "The GitHub App has no access to #{repository.slug}. Grant access on GitHub first.")
      when :no_repository
        Result.new(:failed, "Repository #{repository.slug} was not found on GitHub.")
      when :low_rate_limit
        Result.new(:failed, "GitHub API rate limit is too low right now. Try again later.")
      else
        Result.new(:failed, "Could not refresh #{repository.slug}. Try again later.")
      end
    end
    private_class_method :refresh_cached_repository

    # Repo absent from the cache: re-sync the whole owner installation (async).
    # The caller's claim to the installation is verified in .targeted before we
    # reach here.
    def self.refresh_owner_installation(installation, slug)
      owner = slug.split("/").first

      if Repositories::Worker.new.unique_lock_exists?([installation.installation_id])
        return Result.new(:already_running, "A repository sync is already running. Results will appear shortly.")
      end

      Repositories::Worker.perform_async(installation.installation_id)
      Result.new(:started, "Re-syncing #{owner}'s repository list. Search again in a moment.")
    end
    private_class_method :refresh_owner_installation

    # Whether the repository already shows up in this user's list — i.e. they
    # hold a (push-access) collaborator row for it. Mirrors how #get_repositories
    # builds the list, so "listed" here means exactly "listed in the UI".
    def self.listed_for?(github_uid, slug)
      canonical = GithubAppInstallation.canonical_slug(slug)
      GithubAppCollaborator.where(:c_id => github_uid).where("LOWER(r_name) = ?", canonical).exists?
    end
    private_class_method :listed_for?

    # A user may refresh an installation they collaborate in — the same scope
    # .full grants. Installation-level (not per-repo) on purpose: .full already
    # lets such a user re-sync the installation's entire repository list, so a
    # per-repo refresh within it is strictly narrower.
    def self.user_collaborates_in?(github_uid, installation)
      GithubAppCollaborator.exists?(:c_id => github_uid, :installation_id => installation.installation_id)
    end
    private_class_method :user_collaborates_in?

    def self.github_uid_for(user_id)
      ::User.find(user_id).github_repo_host_account&.github_uid
    rescue ActiveRecord::RecordNotFound
      nil
    end
    private_class_method :github_uid_for
  end
end
