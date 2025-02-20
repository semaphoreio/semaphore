class AddsDeletedAtToOrganizationSuspendion < ActiveRecord::Migration[5.1]
  def change
    add_column :organization_suspensions, :deleted_at, :datetime, null: true
  end
end
