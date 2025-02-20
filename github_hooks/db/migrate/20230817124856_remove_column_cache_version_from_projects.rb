class RemoveColumnCacheVersionFromProjects < ActiveRecord::Migration[5.1]
  def change
    remove_column :projects, :cache_version, :datetime
  end
end
