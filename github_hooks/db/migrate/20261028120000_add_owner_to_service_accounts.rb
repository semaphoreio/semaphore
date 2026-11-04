class AddOwnerToServiceAccounts < ActiveRecord::Migration[6.1]
  # A service account acts for a person, its owner. The column starts empty and is
  # filled from creator_id for creators who are still members of the organization,
  # so it stays nil where no member stands behind the account.
  def change
    # The foreign key takes a lock on users as well, so give up rather than queue behind
    # an open write and hold every reader of both tables behind us.
    reversible { |dir| dir.up { execute "SET LOCAL lock_timeout = '5s'" } }

    add_column :service_accounts, :owner_id, :uuid
    add_index :service_accounts, :owner_id
    add_foreign_key :service_accounts, :users, column: :owner_id, on_delete: :nullify
  end
end
