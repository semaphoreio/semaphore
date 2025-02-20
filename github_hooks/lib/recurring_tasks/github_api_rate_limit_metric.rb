module RecurringTasks
  class GithubApiRateLimitMetric
    include Sidekiq::Worker

    sidekiq_options :queue => :github_app

    REPO_LIMIT = 500

    def perform
      GithubAppInstallation.with_more_than_repos(REPO_LIMIT).each do |installation|
        token, = Semaphore::GithubApp::Token.installation_token(installation.installation_id)
        next unless token

        organization_name = GithubAppInstallation.organization_name(installation)

        client = RepoHost::Github::Client.new(token)
        remaining = client.rate_limit_remaining()

        Watchman.submit("rate_limit_remaining", remaining, :gauge, :tags => [organization_name])
      end
    end
  end
end
