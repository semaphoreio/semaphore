class AddUserDeactivationFields < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :deactivated, :boolean
    add_column :users, :deactivated_at, :timestamp
  end
end
