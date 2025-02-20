class AddProjectIdToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :project_id, :uuid
  end
end
