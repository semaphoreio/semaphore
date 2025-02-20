class AddAllowedSecretsToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :allowed_secrets, :string, null: false, default: ""
  end
end
