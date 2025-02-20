class AddExecutionTimeLimitToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :execution_time_limit, :integer
  end
end
