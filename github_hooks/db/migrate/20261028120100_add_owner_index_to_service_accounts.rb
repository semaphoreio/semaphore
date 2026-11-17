class AddOwnerIndexToServiceAccounts < ActiveRecord::Migration[6.1]
  # Its own step, so a retry resumes here rather than re-entering the column add.
  disable_ddl_transaction!

  def up
    add_index :service_accounts, :owner_id, if_not_exists: true
  end

  def down
    remove_index :service_accounts, :owner_id, if_exists: true
  end
end
