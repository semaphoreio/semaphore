class AddArtifactStoreIdToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :artifact_store_id, :uuid
  end
end
