class AddIndexForJobsCreatedAt < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :jobs, :created_at, algorithm: :concurrently
  end
end
