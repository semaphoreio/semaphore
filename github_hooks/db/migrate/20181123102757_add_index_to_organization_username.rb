class AddIndexToOrganizationUsername < ActiveRecord::Migration[5.1]
  def change
    add_index "organizations", ["username"], unique: true, using: :btree
  end
end
