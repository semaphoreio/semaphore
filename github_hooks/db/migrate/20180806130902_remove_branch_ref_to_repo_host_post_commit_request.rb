class RemoveBranchRefToRepoHostPostCommitRequest < ActiveRecord::Migration[4.2]
  def change
    remove_reference :repo_host_post_commit_requests, :branch, index: true, foreign_key: true
  end
end
