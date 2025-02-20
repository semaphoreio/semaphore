class AddFieldsToGithubAppInstallation < ActiveRecord::Migration[5.1]
  def change
    add_column :github_app_installations, :deleted_at, :timestamp
    add_column :github_app_installations, :suspended_at, :timestamp
    add_column :github_app_installations, :permissions_accepted_at, :timestamp
  end
end
