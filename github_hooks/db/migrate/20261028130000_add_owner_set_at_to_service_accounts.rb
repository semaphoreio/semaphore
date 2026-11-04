class AddOwnerSetAtToServiceAccounts < ActiveRecord::Migration[6.1]
  # Records that an owner was decided, so an account left without one is told apart from
  # one that never had one. Only the latter takes its creator.
  def up
    # Give up rather than queue behind an open write and hold every later reader of the
    # table behind us.
    execute "SET LOCAL lock_timeout = '5s'"

    add_column :service_accounts, :owner_set_at, :datetime

    execute <<~SQL
      UPDATE service_accounts SET owner_set_at = now() AT TIME ZONE 'utc' WHERE owner_id IS NOT NULL
    SQL
  end

  def down
    remove_column :service_accounts, :owner_set_at
  end
end
