class AddCommitStatusToRepositories < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :commit_status, :jsonb
  end
end
