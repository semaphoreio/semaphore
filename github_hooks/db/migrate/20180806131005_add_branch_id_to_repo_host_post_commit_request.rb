class AddBranchIdToRepoHostPostCommitRequest < ActiveRecord::Migration[4.2]
  def change
    add_column :repo_host_post_commit_requests, :branch_id, :uuid

    add_index :repo_host_post_commit_requests, :branch_id
  end
end
