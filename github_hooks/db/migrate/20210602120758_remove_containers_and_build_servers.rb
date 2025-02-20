class RemoveContainersAndBuildServers < ActiveRecord::Migration[5.1]
  def change
    rename_table(:build_servers, :eagles)
    rename_table(:containers, :falcons)
  end
end
