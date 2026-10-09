class AddPullRequestCommitToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :pull_request_commit, :string, null: false, default: "merge_commit"
  end
end
