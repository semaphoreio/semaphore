module RepoHost
  class Factory
    def self.create_repo_host(repo_host_account)
      RepoHost::Github::Client.new(repo_host_account.token)
    end

    def self.create_from_project(project, request_timeout: nil)
      token, = ::Semaphore::ProjectIntegrationToken.new.project_token(project)
      ::RepoHost::Github::Client.new(token, :request_timeout => request_timeout)
    end
  end
end
