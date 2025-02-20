class AddIndexForOrganizationIdOnProjects < ActiveRecord::Migration[5.1]
  def change
    add_index "projects", ["organization_id"], using: :btree
  end
end
