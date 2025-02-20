class AddAgentAuthTokenToJobsTable < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :agent_auth_token, :string
  end
end
