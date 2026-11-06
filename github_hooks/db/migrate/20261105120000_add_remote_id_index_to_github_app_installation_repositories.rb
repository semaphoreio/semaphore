class AddRemoteIdIndexToGithubAppInstallationRepositories < ActiveRecord::Migration[6.1]
  # GithubAppInstallation.find_for_remote_id looks repositories up by remote_id
  # on every webhook and had no index to use. The index is deliberately not
  # unique: remote_id = 0 marks repositories whose id is not backfilled yet, and
  # the same repository can briefly appear under two installations while
  # access is moved between them.
  #
  # A concurrent build that is interrupted leaves an INVALID index behind, and
  # if_not_exists then skips it on the next run. After deploying, check
  #   SELECT indisvalid FROM pg_index
  #   WHERE indexrelid = 'idx_gh_app_inst_repos_on_remote_id'::regclass;
  # If it is false, DROP INDEX CONCURRENTLY idx_gh_app_inst_repos_on_remote_id
  # and run this migration again.
  disable_ddl_transaction!

  def change
    add_index :github_app_installation_repositories,
              :remote_id,
              name: "idx_gh_app_inst_repos_on_remote_id",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
