class AddIndexForBuildIdOnJobs < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :jobs, :build_id, algorithm: :concurrently
  end
end
