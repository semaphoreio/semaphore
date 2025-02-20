class AddOrganizationIdToFavorites < ActiveRecord::Migration[5.1]
  def change
    add_column :favorites, :organization_id, :uuid

    remove_index :favorites, name: :index_favorites_on_user_id_and_favorite_id_and_kind
    remove_index :favorites, name: :index_favorites_on_user_id

    add_index :favorites, [:user_id, :organization_id, :favorite_id, :kind], :unique => true, :name => :favorites_index
    add_index :favorites, [:user_id, :organization_id]
  end
end
