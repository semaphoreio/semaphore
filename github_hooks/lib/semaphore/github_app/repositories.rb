module Semaphore::GithubApp
  class Repositories
    MAX_NUMBER_OF_REPOSITORIES = 10000

    def self.refresh_by_name(organization_name)
      installation = GithubAppInstallation.find_by_organization_name(organization_name)

      return :no_installation unless installation

      new(installation.installation_id).refresh
    end

    def self.refresh(installation_id)
      new(installation_id).refresh
    end

    def initialize(installation_id)
      @installation_id = installation_id
    end

    def refresh
      return :no_token unless client
      return :low_rate_limit if client.rate_limit_remaining() < App.collaborators_api_rate_limit

      Semaphore::GithubApp::Hook.add_repositories(installation_id, repositories_to_add)
      Semaphore::GithubApp::Hook.update_repository_ids(installation_id, repositories_to_update_ids)
      Semaphore::GithubApp::Hook.remove_repositories(installation_id, repositories_to_remove)

      :ok
    rescue ActiveRecord::RecordNotFound
      :no_installation
    end

    def repositories_to_add
      remote_repositories.select do |repository|
        current_repositories_by_slug[canonical_slug(repository["slug"])].nil?
      end
    end

    def repositories_to_remove
      current_repositories.reject do |repository|
        remote_repositories_by_slug.key?(canonical_slug(repository["slug"]))
      end
    end

    def repositories_to_update_ids
      remote_repositories.select do |repository|
        current = current_repositories_by_slug[canonical_slug(repository["slug"])]
        current.present? &&
          (current["id"].to_i != repository["id"].to_i || current["slug"] != repository["slug"])
      end
    end

    def remote_repositories
      @remote_repositores ||= get_remote_repositories
    end

    def current_repositories
      @current_repositories ||= installation.repositories
    end

    private

    attr_reader :installation_id

    def installation
      @installation ||= GithubAppInstallation.find_by!(:installation_id => installation_id)
    end

    def get_remote_repositories
      github_repos = []
      page = 1
      per_page = 100

      loop do
        response = Excon.get(
          "https://api.github.com/installation/repositories?per_page=#{per_page}&page=#{page}",
          :headers => {
            "User-Agent" => "Monolith-GitHubApp-Repositories",
            "Authorization" => "token #{token}",
            "Accept" => "application/vnd.github.v3+json"
          })
        body = JSON.parse(response.data[:body])
        total_count = [body["total_count"].to_i, MAX_NUMBER_OF_REPOSITORIES].min

        github_repos.concat(Semaphore::GithubApp::Hook.map_repositories(body["repositories"]))
        break if page * per_page >= total_count
        page += 1
        sleep 1
      end

      github_repos
    end

    def current_repositories_by_slug
      @current_repositories_by_slug ||= current_repositories.index_by { |repository| canonical_slug(repository["slug"]) }
    end

    def remote_repositories_by_slug
      @remote_repositories_by_slug ||= remote_repositories.index_by { |repository| canonical_slug(repository["slug"]) }
    end

    def canonical_slug(slug)
      GithubAppInstallation.canonical_slug(slug)
    end

    def token
      @token ||= get_token
    end

    def client
      return unless token

      RepoHost::Github::Client.new(token)
    end

    def get_token
      token, _ = Semaphore::GithubApp::Token.installation_token(installation_id)

      token
    end
  end
end
