class AddIpAllowListToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :ip_allow_list, :string, null: false, default: ""
  end
end
