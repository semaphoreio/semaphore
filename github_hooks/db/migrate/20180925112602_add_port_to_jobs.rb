class AddPortToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :port, :integer
  end
end
