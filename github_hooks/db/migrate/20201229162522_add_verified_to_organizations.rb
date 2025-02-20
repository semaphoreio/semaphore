class AddVerifiedToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :verified, :boolean
  end
end
