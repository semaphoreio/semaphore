class AddWhitelistToRepositories < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :whitelist, :jsonb
  end
end
