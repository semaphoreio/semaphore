class AddCommitAuthorToWorkflows < ActiveRecord::Migration[5.1]
  def change
    add_column :workflows, :commit_author, :string
  end
end
