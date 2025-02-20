module RepoHost

  module PullRequest

    def self.details(repo, number, repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)

      repo_host.pull_request(repo, number)
    end

    def self.commits(repo, number, repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)

      repo_host.pull_request_commits(repo, number)
    end

  end

end
