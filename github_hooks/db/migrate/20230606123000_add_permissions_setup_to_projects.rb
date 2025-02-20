class AddPermissionsSetupToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :permissions_setup, :boolean, null: true
  end
end
