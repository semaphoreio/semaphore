class AddBlockedAtToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :blocked_at, :timestamp
  end
end
