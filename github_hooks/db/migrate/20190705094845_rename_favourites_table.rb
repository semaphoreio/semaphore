class RenameFavouritesTable < ActiveRecord::Migration[5.1]
  def change
    rename_column :favourites, :favourite_id, :favorite_id
    rename_table :favourites, :favorites
  end
end
