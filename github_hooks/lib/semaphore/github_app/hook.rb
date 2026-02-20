module Semaphore::GithubApp
  class Hook
    class UnknownAction < ::StandardError; end
    class NotFound < ::StandardError; end

    def self.process(event, payload)
      action = payload["action"]

      installation_id = payload["installation"]["id"]
      repositories = map_repositories(payload["repositories"])
      repositories_added = map_repositories(payload["repositories_added"])
      repositories_removed = map_repositories(payload["repositories_removed"])

      return create(installation_id, repositories) if action == "created"
      return delete(installation_id) if action == "deleted"
      return suspend(installation_id) if action == "suspend"
      return unsuspend(installation_id) if action == "unsuspend"
      return accept_permissions(installation_id) if action == "new_permissions_accepted"

      return add_repositories(installation_id, repositories_added) if action == "added"
      return remove_repositories(installation_id, repositories_removed) if action == "removed"

      Exceptions.notify(
        UnknownAction.new,
        :event => event,
        :action => action
      )

      true
    rescue ActiveRecord::RecordNotFound
      Exceptions.notify(
        NotFound.new,
        :installation_id => installation_id,
        :event => event,
        :action => action
      )

      true
    end

    def self.map_repositories(repositories)
      GithubAppInstallation.normalize_repositories(
        Array(repositories).map { |repo| { "id" => repo["id"], "slug" => repo["full_name"] } }
      )
    end

    def self.create(installation_id, repositories)
      repositories = GithubAppInstallation.normalize_repositories(repositories)
      installation = GithubAppInstallation.create(:installation_id => installation_id, :repositories => repositories)

      repositories.each do |repository|
        slug = repository["slug"]
        next if slug.blank?

        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.connect_github_app_by_slug(slug)
      end
    end

    def self.delete(installation_id)
      installation = get_installation(installation_id)
      repositories = installation.repositories
      installation.destroy

      repositories.each do |repository|
        slug = repository["slug"]
        next if slug.blank?

        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
    end

    def self.suspend(installation_id)
      installation = get_installation(installation_id)
      repositories = installation.repositories
      installation.suspended_at = Time.zone.now
      installation.save

      repositories.each do |repository|
        slug = repository["slug"]
        next if slug.blank?

        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
    end

    def self.unsuspend(installation_id)
      installation = get_installation(installation_id)
      repositories = installation.repositories
      installation.suspended_at = nil
      installation.save

      repositories.each do |repository|
        slug = repository["slug"]
        next if slug.blank?

        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.connect_github_app_by_slug(slug)
      end
    end

    def self.accept_permissions(installation_id)
      installation = get_installation(installation_id)
      installation.permissions_accepted_at = Time.zone.now
      installation.save
    end

    def self.add_repositories(installation_id, repositories)
      installation = get_installation(installation_id)
      repositories = GithubAppInstallation.normalize_repositories(repositories)
      installation.add_repositories!(repositories)

      repositories.each do |repo|
        slug = repo["slug"]

        # GitHub sends us a webhook before API is ready to admit that changes took place.
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.connect_github_app_by_slug(slug)
      end
    end

    def self.remove_repositories(installation_id, repositories)
      installation = get_installation(installation_id)
      repositories = GithubAppInstallation.normalize_repositories(repositories)
      slugs_to_remove = repositories.map { |repository| repository["slug"] }
      installation.remove_repositories_by_slug!(slugs_to_remove)

      repositories.each do |repo|
        slug = repo["slug"]

        # GitHub sends us a webhook before API is ready to admit that changes took place.
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
    end

    def self.update_repository_ids(installation_id, repositories)
      installation = get_installation(installation_id)
      repositories = GithubAppInstallation.normalize_repositories(repositories)
      return if repositories.empty?

      installation.update_repository_ids!(repositories)
    end

    def self.get_installation(installation_id)
      GithubAppInstallation.find_by!(:installation_id => installation_id)
    end

    def self.webhook_signature_valid?(secret, signature, payload)
      signing_secret = secret
      computed_signature = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), signing_secret, payload)}"

      if Rack::Utils.secure_compare(computed_signature, signature)
        :ok
      else
        :not_verified
      end
    end
  end
end
