class AddCacheIdToProject < ActiveRecord::Migration[4.2]
  def change
    add_column :projects, :cache_id, :uuid
  end
end
