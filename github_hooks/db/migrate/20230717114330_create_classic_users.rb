class CreateClassicUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :classic_users, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.string :email, null: false
    end

    add_index "classic_users", ["email"], unique: true
  end
end
