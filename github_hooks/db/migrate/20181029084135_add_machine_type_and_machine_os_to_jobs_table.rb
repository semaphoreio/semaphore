class AddMachineTypeAndMachineOsToJobsTable < ActiveRecord::Migration[5.1]
  def change
    add_column :jobs, :machine_type, :string
    add_column :jobs, :machine_os_image, :string
  end
end
