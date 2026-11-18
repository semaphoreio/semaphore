class AddOwnerForeignKeyToServiceAccounts < ActiveRecord::Migration[6.1]
  # Its own step, so a retry resumes here rather than re-entering the column and index.
  disable_ddl_transaction!

  def up
    add_foreign_key :service_accounts, :users, column: :owner_id, on_delete: :nullify, if_not_exists: true
  end

  def down
    remove_foreign_key :service_accounts, column: :owner_id, if_exists: true
  end
end
