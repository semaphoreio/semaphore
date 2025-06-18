class AddStoppedByToJobStopRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :job_stop_requests, :stopped_by, :string
    add_column :jobs, :stopped_by, :string
  end
end
