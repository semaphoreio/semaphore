module Semaphore::GithubApp
  class Hook
    class UnknownAction < ::StandardError; end
    class NotFound < ::StandardError; end

    def self.process(event, payload)
      action = payload["action"]

      installation_id = payload["installation"]["id"]
      repositories = map_repositories_name(payload["repositories"])
      repositories_added = map_repositories_name(payload["repositories_added"])
      repositories_removed = map_repositories_name(payload["repositories_removed"])

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

    def self.map_repositories_name(repositories)
      Array(repositories).map { |repo| repo["full_name"] }
    end

    def self.create(installation_id, repositories)
      installation = GithubAppInstallation.create(:installation_id => installation_id, :repositories => repositories)

      installation.repositories.each do |slug|
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.connect_github_app_by_slug(slug)
      end
    end

    def self.delete(installation_id)
      installation = get_installation(installation_id)
      installation.destroy

      installation.repositories.each do |slug|
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
    end

    def self.suspend(installation_id)
      installation = get_installation(installation_id)
      installation.suspended_at = Time.zone.now
      installation.save

      installation.repositories.each do |slug|
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
    end

    def self.unsuspend(installation_id)
      installation = get_installation(installation_id)
      installation.suspended_at = nil
      installation.save

      installation.repositories.each do |slug|
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
      sql = <<-SQL
      UPDATE github_app_installations
      SET repositories = (SELECT to_jsonb(array_agg(DISTINCT b)) FROM (SELECT jsonb_array_elements_text(repositories || $1::jsonb) AS b FROM github_app_installations WHERE installation_id = $2 ) AS c )
      WHERE installation_id = $2
      SQL

      GithubAppInstallation.connection.exec_update(sql, "Adds GitHub App repositories", [repositories.to_json, installation_id])

      repositories.each do |slug|
        # GitHub sends us a webhook before API is ready to admit that changes took place.
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.connect_github_app_by_slug(slug)
      end
    end

    def self.remove_repositories(installation_id, repositories)
      sql = <<-SQL
      UPDATE github_app_installations
      SET repositories = to_jsonb(array_diff((SELECT array_agg(trim(JsonString::text, '"')) FROM jsonb_array_elements(repositories) JsonString), $2::text[]))
      WHERE installation_id = $1
      SQL

      GithubAppInstallation.connection.exec_update(sql, "Removes GitHub App repositories", [installation_id, "{#{repositories.join(",")}}"])

      repositories.each do |slug|
        # GitHub sends us a webhook before API is ready to admit that changes took place.
        Semaphore::GithubApp::Collaborators::Worker.perform_in(10, slug)
        ::Repository.disconnect_github_app_by_slug(slug)
      end
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
