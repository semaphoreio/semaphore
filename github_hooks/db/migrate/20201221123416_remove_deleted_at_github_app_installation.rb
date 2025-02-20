class RemoveDeletedAtGithubAppInstallation < ActiveRecord::Migration[5.1]
  def change
    remove_column :github_app_installations, :deleted_at, :timestamp
  end
end
