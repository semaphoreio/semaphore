class AddRevokedToRepoHostAccount < ActiveRecord::Migration[5.1]
  def change
    add_column :repo_host_accounts, :revoked, :boolean, null: false, default: false
  end
end
