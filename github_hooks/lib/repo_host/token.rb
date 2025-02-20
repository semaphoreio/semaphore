module RepoHost
  module Token

    def self.valid?(repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)
      repo_host.token_valid?
    end

    def self.revoke_connection(repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)
      repo_host.revoke_connection
    end

  end
end
