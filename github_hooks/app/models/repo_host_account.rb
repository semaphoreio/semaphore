class RepoHostAccount < ActiveRecord::Base
  belongs_to :user

  scope :by_user, -> (user_id) { where(user_id: user_id) }
  scope :github, -> { where(:repo_host => ::Repository::GITHUB_PROVIDER) }
  scope :bitbucket, -> { where(:repo_host => ::Repository::BITBUCKET_PROVIDER) }

  def private_scope?
    !revoked? && permission_scope.start_with?("repo")
  end

  def public_scope?
    !revoked? && (permission_scope.start_with?("public_repo") || private_scope?)
  end
end
