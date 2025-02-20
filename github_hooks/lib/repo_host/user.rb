module RepoHost

  module User

    def self.repositories(repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)
      repo_host_login = repo_host_account.login

      repositories_for_repo_host(repo_host, repo_host_login)
    end

    def self.group_repositories(repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)

      repo_host.group_repositories
    end

    def self.organizations(repo_host_account)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)

      repo_host.organizations
    end

    def self.emails(repo_host_account)
      path = "/user/emails"

      RepoHost.get(path, repo_host_account.token)
    end

    def self.user(repo_host_account, login)
      repo_host = RepoHost::Factory.create_repo_host(repo_host_account)

      repo_host.user(login)
    end

    private

    def self.repositories_for_repo_host(repo_host, repo_host_login)
      repositories = repo_host.repositories

      case repo_host
      when RepoHost::Github::Client
        repositories.select { |repo| repo.owner[:login] == repo_host_login }
      else
        []
      end
    end

  end

end
