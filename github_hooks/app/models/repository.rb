class Repository < ActiveRecord::Base
  GITHUB_PROVIDER = "github"
  BITBUCKET_PROVIDER = "bitbucket"
  DEFAULT_PROVIDER = GITHUB_PROVIDER

  belongs_to :project, optional: true

  def self.disconnect_github_app(repository_slug: nil, repository_remote_id: nil)
    update_github_app_connection(
      :repository_slug => repository_slug,
      :repository_remote_id => repository_remote_id,
      :connected => false
    )
  end

  def self.connect_github_app(repository_slug: nil, repository_remote_id: nil)
    update_github_app_connection(
      :repository_slug => repository_slug,
      :repository_remote_id => repository_remote_id,
      :connected => true
    )
  end

  def self.update_github_app_connection(repository_slug:, repository_remote_id:, connected:)
    repositories_for_github_app(repository_slug: repository_slug, repository_remote_id: repository_remote_id).each do |repo|
      repo.update(:connected => connected)
      ::Project.publish_updated(repo.project)
    end
  end
  private_class_method :update_github_app_connection

  def self.repositories_for_github_app(repository_slug:, repository_remote_id:)
    scope = where(:integration_type => "github_app")

    if repository_remote_id.present?
      repositories = scope.where(:remote_id => repository_remote_id.to_s).includes(:project).to_a
      return repositories if repositories.any?
    end

    if repository_slug.present?
      return scope.where(:url => "git@github.com:#{repository_slug}.git").includes(:project)
    end

    scope.none
  end
  private_class_method :repositories_for_github_app
end
