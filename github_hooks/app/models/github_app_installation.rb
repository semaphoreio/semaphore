class GithubAppInstallation < ActiveRecord::Base
  has_many :contributors, :class_name => "GithubAppCollaborator", :inverse_of => :installation, :dependent => :delete_all, :primary_key => :installation_id, :foreign_key => :installation_id

  def self.find_for_repository!(repository_slug)
    where("repositories::text ilike '%\"#{repository_slug}\"%'").first!
  end

  def self.find_for_repository(repository_slug)
    where("repositories::text ilike '%\"#{repository_slug}\"%'").first
  end

  def self.find_for_organization!(organization_name)
    where("repositories::text ilike '%\"#{organization_name}/%\"%'").first!
  end

  def self.with_more_than_repos(limit)
    where("jsonb_array_length(repositories) > ?", limit)
  end

  def self.organization_name(installation)
    repo = installation.repositories.find { |repo| repo.to_s != "" }
    return unless repo

    repo.split("/")[0]
  end
end
