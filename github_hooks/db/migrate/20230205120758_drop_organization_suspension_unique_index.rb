class DropOrganizationSuspensionUniqueIndex < ActiveRecord::Migration[5.1]
  def up
    remove_index :organization_suspensions, :name => "index_organization_suspensions_on_organization_id_and_reason"
  end

  def down
    add_index :organization_suspensions, [:organization_id, :reason], :unique => true
  end
end
