class AddEncryptedTokenColumn < ActiveRecord::Migration[5.1]
  def change
    add_column :repo_host_accounts, :encrypted_token, :bytea, default: nil
  end
end
