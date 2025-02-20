class AddSuspendedToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :suspended, :boolean, default: false
  end
end
