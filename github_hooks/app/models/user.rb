class User < ActiveRecord::Base
  has_many :repo_host_accounts, :dependent => :destroy

  def self.find_by_provider_login(login, provider)
    RepoHostAccount.find_by(:repo_host => provider, :login => login)&.user
  end

  def github_repo_host_account
    repo_host_account(::Repository::GITHUB_PROVIDER)
  end

  def bitbucket_repo_host_account
    repo_host_account(::Repository::BITBUCKET_PROVIDER)
  end

  def repo_host_account(repo_host)
    repo_host_accounts.find_by_repo_host(repo_host)
  end
end
