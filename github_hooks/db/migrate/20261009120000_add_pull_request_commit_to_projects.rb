class AddPullRequestCommitToProjects < ActiveRecord::Migration[8.0]
  def up
    execute "SET LOCAL lock_timeout = '5s'"
    add_column :projects, :pull_request_commit, :string, null: false, default: "merge_commit", if_not_exists: true
  end

  def down
    remove_column :projects, :pull_request_commit, if_exists: true
  end
end
