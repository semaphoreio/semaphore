class Repository < ActiveRecord::Base
  GITHUB_PROVIDER = "github"
  BITBUCKET_PROVIDER = "bitbucket"
  DEFAULT_PROVIDER = GITHUB_PROVIDER

  belongs_to :project, optional: true

  def self.disconnect_github_app_by_slug(repository_slug)
    where(
      :integration_type => "github_app",
      :url => "git@github.com:#{repository_slug}.git"
    ).includes(:project).each do |repo|
      repo.update(:connected => false)
      ::Project.publish_updated(repo.project)
    end
  end

  def self.connect_github_app_by_slug(repository_slug)
    where(
      :integration_type => "github_app",
      :url => "git@github.com:#{repository_slug}.git"
    ).includes(:project).each do |repo|
      repo.update(:connected => true)
      ::Project.publish_updated(repo.project)
    end
  end
end
