class AddUserIdToMigrations < ActiveRecord::Migration[5.1]
  def change
    add_column :debugs, :user_id, :uuid
  end
end
