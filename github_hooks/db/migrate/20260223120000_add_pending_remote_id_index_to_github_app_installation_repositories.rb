class AddPendingRemoteIdIndexToGithubAppInstallationRepositories < ActiveRecord::Migration[5.1]
  def up
    add_index :github_app_installation_repositories,
              :installation_id,
              :where => "remote_id = 0",
              :name => "idx_gh_app_inst_repos_pending_remote_id"
  end

  def down
    remove_index :github_app_installation_repositories, :name => "idx_gh_app_inst_repos_pending_remote_id"
  end
end
