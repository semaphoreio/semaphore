class AddRepositoryIdToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :repository_id, :uuid
  end
end
