class AddAgentInfoToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :agent_id, :uuid
    add_column :jobs, :agent_ip_address, :string
    add_column :jobs, :agent_ctrl_port, :integer
  end
end
