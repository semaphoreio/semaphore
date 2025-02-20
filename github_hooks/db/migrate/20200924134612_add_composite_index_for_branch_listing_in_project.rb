class AddCompositeIndexForBranchListingInProject < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  #
  # Listing branches in Internal API
  #
  # With this index we will be listing branches with archived ones.
  #
  def change
    add_index :branches, [:project_id, :used_at],
      order: { used_at: "DESC" },

      algorithm: :concurrently
  end
end
