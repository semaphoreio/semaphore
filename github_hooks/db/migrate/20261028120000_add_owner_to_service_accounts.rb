class AddOwnerToServiceAccounts < ActiveRecord::Migration[6.1]
  # add_column deallocates the prepared statement cache first, which aborts the
  # surrounding transaction when a cached statement outlived the backend it was
  # prepared on. Outside a transaction the step stands alone, and it is conditional.
  disable_ddl_transaction!

  # A service account acts for a person, its owner. The column starts empty and is
  # filled from creator_id for creators who are still members of the organization,
  # so it stays nil where no member stands behind the account.
  def up
    add_column :service_accounts, :owner_id, :uuid, if_not_exists: true
  end

  def down
    remove_column :service_accounts, :owner_id, if_exists: true
  end
end
