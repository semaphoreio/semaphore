class AddPriorityToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :priority, :integer
  end
end
