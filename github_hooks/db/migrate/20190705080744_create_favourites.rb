class CreateFavourites < ActiveRecord::Migration[5.1]
  def change
    create_table :favourites, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.uuid "user_id"
      t.uuid "favourite_id"
      t.string "type"
    end
  end
end
