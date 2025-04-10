class AddDeletedAtForProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :deleted_at, :datetime, null: true, default: nil
    add_column :projects, :deleted_by, :uuid, null: true, default: nil
  end
end
