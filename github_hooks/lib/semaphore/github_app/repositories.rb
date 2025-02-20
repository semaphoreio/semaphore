module Semaphore::GithubApp
  class Repositories
    MAX_NUMBER_OF_REPOSITORIES = 10000

    def self.refresh_by_name(organization_name)
      installation = GithubAppInstallation.all.detect do |g|
        (g.repositories || []).detect(&:present?).to_s.split("/")[0] == organization_name
      end

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
      Semaphore::GithubApp::Hook.remove_repositories(installation_id, repositories_to_remove)

      :ok
    rescue ActiveRecord::RecordNotFound
      :no_installation
    end

    def repositories_to_add
      remote_repositories - current_repositories
    end

    def repositories_to_remove
      current_repositories - remote_repositories
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
        total_count = [JSON.parse(response.data[:body])["total_count"].to_i, MAX_NUMBER_OF_REPOSITORIES].min

        github_repos = github_repos + JSON.parse(response.data[:body])["repositories"].map { |repo| repo["full_name"] }
        break if page * per_page > total_count
        page += 1
        sleep 1
      end

      github_repos
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
