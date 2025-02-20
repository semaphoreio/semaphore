class IndexJobsOnResult < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :jobs, :result, algorithm: :concurrently
  end
end
