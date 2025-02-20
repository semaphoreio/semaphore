module Semaphore::GithubApp
  class Collaborators
    def self.refresh(repository_slug)
      client = new_client(repository_slug)

      return :no_token unless client
      return :low_rate_limit if client.rate_limit_remaining() < App.collaborators_api_rate_limit

      github_collaborators = fetch_collaborators(client, repository_slug)
      current_uids = GithubAppCollaborator.where(:r_name => repository_slug).pluck(:c_id)
      github_uids  = github_collaborators.map { |gc| gc["id"] }

      remove_collaborators(repository_slug, current_uids - github_uids)
      add_collaborators(repository_slug, github_uids - current_uids, github_collaborators)

      :ok
    rescue RepoHost::RemoteException::NotFound
      :no_repository
    end

    # PRIVATE

    def self.remove_collaborators(repository_slug, github_uids)
      GithubAppCollaborator.where(:r_name => repository_slug, :c_id => github_uids).delete_all
    end

    def self.add_collaborators(repository_slug, github_uids, github_collaborators)
      return unless github_uids.any?

      installation = GithubAppInstallation.find_for_repository!(repository_slug)

      github_uids.each do |github_uid|
        collaborator = github_collaborators.find { |gc| gc["id"] == github_uid }
        next unless collaborator

        GithubAppCollaborator.create(
          :r_name => repository_slug,
          :c_id => collaborator["id"],
          :c_name => collaborator["login"],
          :installation_id => installation.installation_id
        )
      end
    end

    def self.fetch_collaborators(client, repository_slug)
      client.collaborators(repository_slug).select { |col| col["permissions"]["push"] }
    end

    def self.new_client(repository_slug)
      token, = Semaphore::GithubApp::Token.repository_token(repository_slug)
      return unless token

      RepoHost::Github::Client.new(token)
    end
  end
end
