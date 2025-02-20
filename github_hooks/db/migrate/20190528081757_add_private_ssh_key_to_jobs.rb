class AddPrivateSshKeyToJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :private_ssh_key, :text
  end
end
