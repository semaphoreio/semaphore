class AddDeletedAtForOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :deleted_at, :datetime, null: true, default: nil
    add_column :organizations, :deleted_by, :uuid, null: true, default: nil
  end
end