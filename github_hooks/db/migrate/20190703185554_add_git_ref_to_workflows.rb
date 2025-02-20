class AddGitRefToWorkflows < ActiveRecord::Migration[5.1]
  def change
    add_column :workflows, :git_ref, :string
  end
end
