module Semaphore::GithubApp
  # Manual re-sync of the GitHub App repository/collaborator cache, triggered
  # by users from the project onboarding UI when the cache went stale (e.g. a
  # missed webhook). Reuses the same Sidekiq workers the webhook handlers
  # enqueue, so unique locks and rate-limit backoff keep duplicate or abusive
  # refreshes in check.
  class RepositoryRefresh
    Result = Struct.new(:state, :message)

    COLLABORATORS_ENQUEUE_DELAY = 10.seconds

    def self.full
      installations = GithubAppInstallation.where(:suspended_at => nil)

      if installations.empty?
        return Result.new(:failed, "No active GitHub App installations found. Install the GitHub App first.")
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

    def self.targeted(repository_slug)
      slug = GithubAppInstallation.normalize_slug(repository_slug)
      return Result.new(:failed, "Use the owner/repository format.") unless slug

      installation = GithubAppInstallation.find_for_repository(slug)

      if installation
        refresh_cached_repository(installation, slug)
      else
        refresh_owner_installation(slug)
      end
    end

    def self.refresh_installation(installation)
      Repositories::Worker.perform_async(installation.installation_id)

      installation.installation_repositories.select(:slug, :remote_id).each do |repository|
        Collaborators::Worker.perform_in(COLLABORATORS_ENQUEUE_DELAY, repository.slug, repository.remote_id)
      end
    end
    private_class_method :refresh_installation

    # Refresh collaborators with the stored slug/remote_id, not the user-typed
    # slug — GithubAppCollaborator rows must keep the API-provided casing.
    def self.refresh_cached_repository(installation, slug)
      canonical = GithubAppInstallation.canonical_slug(slug)
      repository = installation.installation_repositories.where("LOWER(slug) = ?", canonical).first

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

    # The repository is not in the cache (e.g. a missed "repositories added"
    # webhook): re-sync the owner's installation repository list. Async — a
    # full list sync can take hundreds of paginated GitHub API calls.
    def self.refresh_owner_installation(slug)
      owner = slug.split("/").first
      installation = GithubAppInstallation.find_for_organization(owner)

      unless installation
        return Result.new(:failed, "The GitHub App has no access to #{slug}. Grant access on GitHub first.")
      end

      if Repositories::Worker.new.unique_lock_exists?([installation.installation_id])
        return Result.new(:already_running, "A repository sync is already running. Results will appear shortly.")
      end

      Repositories::Worker.perform_async(installation.installation_id)
      Result.new(:started, "Re-syncing #{owner}'s repository list. Search again in a moment.")
    end
    private_class_method :refresh_owner_installation
  end
end
