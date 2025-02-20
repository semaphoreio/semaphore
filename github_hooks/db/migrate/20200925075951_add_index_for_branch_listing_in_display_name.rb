class AddIndexForBranchListingInDisplayName < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  #
  # Listing branches in Internal API
  #
  # With this index we will be listing branches with archived ones.
  #
  # Rails 5.1 is not supporting `opclass` option in `add_index` that's why
  # we are using raw sql here
  def change
    add_index :branches, "display_name gin_trgm_ops",
      using: :gin,
      algorithm: :concurrently
  end
end
