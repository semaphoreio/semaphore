class IndexJobsOnFinishedAt < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :jobs, :finished_at, algorithm: :concurrently
  end
end
