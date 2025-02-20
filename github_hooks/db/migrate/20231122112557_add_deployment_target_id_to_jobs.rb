class AddDeploymentTargetIdToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :deployment_target_id, :uuid
  end
end
