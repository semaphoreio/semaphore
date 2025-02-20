class AddIdProviderToOrg < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :allowed_id_providers, :string, null: false, default: ""
  end
end
