class AddAgentNameToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :agent_name, :string
  end
end
