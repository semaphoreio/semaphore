class AddTokenExpiresAtToRepoHostAccounts < ActiveRecord::Migration[5.1]
  def change
    add_column :repo_host_accounts, :token_expires_at, :datetime, null: true, default: nil
  end
end
