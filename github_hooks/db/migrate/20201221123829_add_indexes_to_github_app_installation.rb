class AddIndexesToGithubAppInstallation < ActiveRecord::Migration[5.1]
  def change
    add_index "github_app_installations", ["installation_id"], using: :btree
    add_index "github_app_installations", ["repositories"], using: :gin
    change_column_null "github_app_installations", "installation_id", false
  end
end
