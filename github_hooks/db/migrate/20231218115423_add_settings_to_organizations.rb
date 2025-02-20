class AddSettingsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :settings, :jsonb
  end
end
