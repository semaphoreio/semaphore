class AddOwnerSetAtToServiceAccounts < ActiveRecord::Migration[6.1]
  # add_column deallocates the prepared statement cache first, which aborts the
  # surrounding transaction when a cached statement outlived the backend it was
  # prepared on. Outside a transaction each step stands alone, and each is conditional.
  disable_ddl_transaction!

  # Records that an owner was decided, so an account left without one is told apart from
  # one that never had one. Only the latter takes its creator.
  def up
    add_column :service_accounts, :owner_set_at, :datetime, if_not_exists: true

    execute <<~SQL
      UPDATE service_accounts SET owner_set_at = now() AT TIME ZONE 'utc'
       WHERE owner_id IS NOT NULL AND owner_set_at IS NULL
    SQL
  end

  def down
    remove_column :service_accounts, :owner_set_at, if_exists: true
  end
end
