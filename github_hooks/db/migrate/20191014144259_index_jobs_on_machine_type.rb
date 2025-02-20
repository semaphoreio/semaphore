class IndexJobsOnMachineType < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :jobs, :machine_type, algorithm: :concurrently
  end
end
