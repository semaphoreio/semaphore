class IndexJobsOnFinishedAtIdAndCreatedAtId < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  #
  # Joined indexes are necessary for fast cursor based API that do either:
  #
  #   - order by created_at asc, id asc
  #   - order by finished_at asc, id asc
  #
  def change
    add_index :jobs, [:created_at, :id], algorithm: :concurrently
    add_index :jobs, [:finished_at, :id], algorithm: :concurrently
  end
end
