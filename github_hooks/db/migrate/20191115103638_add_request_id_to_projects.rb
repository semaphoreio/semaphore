class AddRequestIdToProjects < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :request_id, :uuid

    add_index :projects, :request_id, unique: true
  end
end
