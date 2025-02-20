class AddCommitShaToWorkflows < ActiveRecord::Migration[5.1]
  def change
    add_column :workflows, :commit_sha, :string
  end
end
