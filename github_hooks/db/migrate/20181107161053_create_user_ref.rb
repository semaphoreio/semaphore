class CreateUserRef < ActiveRecord::Migration[5.1]
  def change
    create_table :user_refs, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.references :user, type: :uuid, index: true, foreign_key: true

      t.string :entry_url
      t.string :http_referer
    end
  end
end
