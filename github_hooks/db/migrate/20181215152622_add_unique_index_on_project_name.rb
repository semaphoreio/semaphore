class AddUniqueIndexOnProjectName < ActiveRecord::Migration[5.1]
  def change
    add_index "projects", ["organization_id", "name"], unique: true, using: :btree
  end
end
