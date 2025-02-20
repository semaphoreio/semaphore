class AddHookSecretEncToRepositories < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :hook_secret_enc, :binary, null: true, default: nil
  end
end
