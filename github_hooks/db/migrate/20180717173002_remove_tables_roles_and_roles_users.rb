class RemoveTablesRolesAndRolesUsers < ActiveRecord::Migration[4.2]
  def change
    drop_table :roles
    drop_table :roles_users
  end
end
