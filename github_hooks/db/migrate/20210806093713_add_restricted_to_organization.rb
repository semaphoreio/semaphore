class AddRestrictedToOrganization < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :restricted, :boolean, null: false, default: false
  end
end
