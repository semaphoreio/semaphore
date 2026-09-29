class AddOriginalJobIdToJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :jobs, :original_job_id, :uuid, if_not_exists: true
  end
end
