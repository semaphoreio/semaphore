class RenamePostCommitRequestColumnToWorkflowIdColumn < ActiveRecord::Migration[5.0]
  def change
    rename_column :builds, :repo_host_post_commit_request_id, :workflow_id
  end
end
