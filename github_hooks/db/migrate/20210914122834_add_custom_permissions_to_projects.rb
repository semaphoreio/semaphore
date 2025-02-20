class AddCustomPermissionsToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :custom_permissions, :boolean, null: false, default: false
  end
end
