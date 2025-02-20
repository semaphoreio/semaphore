class IndexBuildsOnResult < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :builds, :result, algorithm: :concurrently
  end
end
