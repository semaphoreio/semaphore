class AddRefreshTokenToRepoHostAccount < ActiveRecord::Migration[5.1]
  def change
    add_column :repo_host_accounts, :refresh_token, :string
  end
end
