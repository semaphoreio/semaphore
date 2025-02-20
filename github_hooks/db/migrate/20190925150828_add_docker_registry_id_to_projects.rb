class AddDockerRegistryIdToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :docker_registry_id, :uuid
  end
end
