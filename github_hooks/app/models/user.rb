class User < ActiveRecord::Base
  has_many :repo_host_accounts, :dependent => :destroy

  def self.find_by_provider_login(login, provider)
    RepoHostAccount.find_by(:repo_host => provider, :login => login)&.user
  end

  def github_repo_host_account
    account = repo_host_account(::Repository::GITHUB_PROVIDER)
    return account if account.present?

    synthetic_repo_host_account
  end

  def bitbucket_repo_host_account
    repo_host_account(::Repository::BITBUCKET_PROVIDER)
  end

  def repo_host_account(repo_host)
    repo_host_accounts.find_by_repo_host(repo_host)
  end

  def service_account?
    creation_source == "service_account"
  end

  private

  def synthetic_repo_host_account
    @synthetic_repo_host_account ||= SyntheticRepoHostAccount.new(self)
  end

  class SyntheticRepoHostAccount
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def name
      user.name || fallback_name
    end

    def github_uid
      prefix = user.service_account? ? "service_account" : "user"
      "#{prefix}_#{user.id}".hash.abs.to_s
    end

    def login
      user.service_account? ? "service-account" : github_uid
    end

    def repo_host
      ::Repository::GITHUB_PROVIDER
    end

    private

    def fallback_name
      user.service_account? ? "Service Account" : ""
    end
  end
end
