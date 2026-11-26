class AddPullRequestCommitToProjects < ActiveRecord::Migration[8.0]
  def up
    execute "SET LOCAL lock_timeout = '5s'"
    execute "ALTER TABLE projects ADD COLUMN IF NOT EXISTS pull_request_commit varchar DEFAULT 'merge_commit' NOT NULL"
  end

  def down
    execute "ALTER TABLE projects DROP COLUMN IF EXISTS pull_request_commit"
  end
end
