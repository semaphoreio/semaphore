class AddBranchRefToRepoHostPostCommitRequest < ActiveRecord::Migration[4.2]
  def change
    add_reference :repo_host_post_commit_requests, :branch,
      :index => true,
      :foreign_key => true,
      :type => :uuid
  end
end
