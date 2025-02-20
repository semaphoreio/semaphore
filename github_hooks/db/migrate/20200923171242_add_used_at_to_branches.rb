class AddUsedAtToBranches < ActiveRecord::Migration[5.1]
  def change
    add_column :branches, :used_at, :timestamp
  end
end
