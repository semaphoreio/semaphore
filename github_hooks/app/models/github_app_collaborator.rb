class GithubAppCollaborator < ActiveRecord::Base
  belongs_to :installation, :class_name => "GithubAppInstallation", :inverse_of => :contributors, :primary_key => :installation_id, :foreign_key => :installation_id
end
