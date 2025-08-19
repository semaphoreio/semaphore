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

  def service_account?
    # Use proper ActiveRecord query to check service_accounts table
    return @is_service_account if defined?(@is_service_account)
    @is_service_account = ActiveRecord::Base.connection.exec_query(
      "SELECT 1 FROM service_accounts WHERE id = $1 LIMIT 1", 
      "Check Service Account", 
      [id]
    ).any?
  end

  def github_repo_host_account_for_project(project = nil)
    # For service accounts, try to use project owner's credentials instead
    if service_account? && project.present?
      project_owner = find_project_owner(project)
      if project_owner&.github_repo_host_account.present?
        return project_owner.github_repo_host_account
      end
    end
    
    # Return user's own account or mock for service accounts
    github_repo_host_account_or_mock
  end

  def github_repo_host_account_or_mock
    account = github_repo_host_account
    return account if account.present?
    
    # Return mock account for service accounts
    if service_account?
      MockRepoHostAccount.new(self)
    else
      nil
    end
  end

  private

  def find_project_owner(project)
    # Try to find a project owner/admin with GitHub integration
    # First try organization members with GitHub accounts
    if project.organization.present?
      # Look for organization members with GitHub accounts
      owner_candidates = ActiveRecord::Base.connection.exec_query(
        <<-SQL,
          SELECT u.* FROM users u
          INNER JOIN members m ON m.user_id = u.id
          INNER JOIN repo_host_accounts rha ON rha.user_id = u.id
          WHERE m.organization_id = $1 
            AND rha.repo_host = 'github'
            AND rha.revoked = false
          ORDER BY m.created_at ASC
          LIMIT 1
        SQL
        "Find Project Owner",
        [project.organization.id]
      )
      
      if owner_candidates.any?
        return User.find(owner_candidates.first['id'])
      end
    end
    
    # Fallback: find any user with GitHub account associated with the project
    # This could be improved by checking project collaborators or repository ownership
    nil
  end

  public

  # Mock repository host account for service accounts (fallback)
  class MockRepoHostAccount
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def name
      "Service Account (#{user.email&.split('@')&.first || user.id})"
    end

    def github_uid
      # Generate a deterministic fake GitHub UID based on user ID
      # Use negative numbers to avoid conflicts with real GitHub UIDs
      -(user.id.to_s.hash.abs % 1000000)
    end

    def login
      name
    end

    def repo_host
      ::Repository::GITHUB_PROVIDER
    end
  end
end
