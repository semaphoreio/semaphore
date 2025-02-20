class AddVisitedAtToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :visited_at, :datetime, null: true
  end
end
