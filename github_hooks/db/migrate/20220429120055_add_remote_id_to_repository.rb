class AddRemoteIdToRepository < ActiveRecord::Migration[5.1]
  def change
    add_column :repositories, :remote_id, :string, null: false, default: ""
  end
end
