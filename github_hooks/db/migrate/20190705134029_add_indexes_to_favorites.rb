class AddIndexesToFavorites < ActiveRecord::Migration[5.1]
  def change
    add_index :favorites, [:user_id, :favorite_id, :kind], :unique => true
    add_index :favorites, :user_id
  end
end
