class AddPrivateKeyEncToDeployKeys < ActiveRecord::Migration[5.1]
  def change
    add_column :deploy_keys, :private_key_enc, :binary, null: true, default: nil
  end
end
