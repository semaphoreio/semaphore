class AddIndexesToWorkflows < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index :workflows, [:repository_id, :received_at],
      where: "repository_id IS NOT NULL",
      name: "one_hook_received_at_per_repository",
      algorithm: :concurrently

    add_index :workflows, [:provider, :state, :created_at],
      algorithm: :concurrently
  end
end
