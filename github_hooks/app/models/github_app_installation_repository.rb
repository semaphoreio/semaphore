class GithubAppInstallationRepository < ActiveRecord::Base
  belongs_to :installation, :class_name => "GithubAppInstallation", :inverse_of => :installation_repositories, :primary_key => :installation_id, :optional => true

  validates :installation_id, :slug, :presence => true
end
