class RemoveUsernameFromUser < ActiveRecord::Migration[4.2]
  def up
    remove_column :users, :username
  end

  def down
    add_column :users, :username, :string
  end
end
