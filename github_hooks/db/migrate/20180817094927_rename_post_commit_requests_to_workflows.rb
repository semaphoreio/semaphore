class RenamePostCommitRequestsToWorkflows < ActiveRecord::Migration[5.0]
  def change
    rename_table :repo_host_post_commit_requests, :workflows
  end
end
