class AddOpenSourceToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :open_source, :boolean, default: false, null: false
  end
end
