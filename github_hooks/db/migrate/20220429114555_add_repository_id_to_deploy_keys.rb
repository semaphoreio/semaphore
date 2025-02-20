class AddRepositoryIdToDeployKeys < ActiveRecord::Migration[5.1]

  def change
    add_column :deploy_keys, :repository_id, :uuid
  end
end
