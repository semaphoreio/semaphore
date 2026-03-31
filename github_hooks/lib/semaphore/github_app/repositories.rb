module Semaphore::GithubApp
  class Repositories
    class IncompleteRepositoryListError < StandardError; end
    class InvalidRepositoryListResponseError < StandardError; end

    MAX_NUMBER_OF_REPOSITORIES = 10000
    PER_PAGE = 100
    EXCON_RETRY_LIMIT = 4

    def self.refresh_by_name(organization_name)
      installation = GithubAppInstallation.find_for_organization(organization_name)

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
      remote_repositories.select do |repository|
        current_repositories_by_slug[canonical_slug(repository["slug"])].nil?
      end
    end

    def repositories_to_remove
      current_repositories.reject do |repository|
        remote_repositories_by_slug.key?(canonical_slug(repository["slug"]))
      end
    end

    def remote_repositories
      @remote_repositores ||= get_remote_repositories
    end

    def current_repositories
      @current_repositories ||= installation.installation_repositories.map do |repository|
        { "id" => repository.remote_id, "slug" => repository.slug }
      end
    end

    private

    attr_reader :installation_id

    def installation
      @installation ||= GithubAppInstallation.find_by!(:installation_id => installation_id)
    end

    def get_remote_repositories
      github_repos = []
      expected_total_count = nil
      next_page_url = "https://api.github.com/installation/repositories?per_page=#{PER_PAGE}&page=1"

      while next_page_url
        response = Excon.get(
          next_page_url,
          :headers => github_api_headers,
          :idempotent => true,
          :retry_limit => EXCON_RETRY_LIMIT,
          :expects => [200]
        )

        body = JSON.parse(response.data[:body])
        repositories = body["repositories"]
        raise InvalidRepositoryListResponseError, "Missing repositories in GitHub App installation repositories response" unless repositories.is_a?(Array)

        total_count = [body["total_count"].to_i, MAX_NUMBER_OF_REPOSITORIES].min
        expected_total_count ||= total_count
        raise IncompleteRepositoryListError, "GitHub App installation repository count changed during pagination" if total_count != expected_total_count

        remaining_slots = expected_total_count - github_repos.size
        github_repos.concat(Semaphore::GithubApp::Hook.map_repositories(repositories.first(remaining_slots)))

        break if github_repos.size >= expected_total_count

        next_page_url = next_page_url(response.headers)
      end

      if expected_total_count.nil? || github_repos.size != expected_total_count
        raise IncompleteRepositoryListError, "Fetched #{github_repos.size} repositories, expected #{expected_total_count || 0}"
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

    def github_api_headers
      {
        "User-Agent" => "Monolith-GitHubApp-Repositories",
        "Authorization" => "token #{token}",
        "Accept" => "application/vnd.github.v3+json"
      }
    end

    def client
      return unless token

      RepoHost::Github::Client.new(token)
    end

    def get_token
      token, _ = Semaphore::GithubApp::Token.installation_token(installation_id)

      token
    end

    def next_page_url(headers)
      link_header = headers["Link"] || headers["link"]
      return if link_header.to_s.empty?

      link_header.split(",").each do |link|
        url, rel = link.split(";").map(&:strip)
        return url.delete_prefix("<").delete_suffix(">") if rel == 'rel="next"'
      end

      nil
    end
  end
end
