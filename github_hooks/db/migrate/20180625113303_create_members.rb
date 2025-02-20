class CreateMembers < ActiveRecord::Migration[4.2]
  def change
    create_table :members, force: :cascade, id: :uuid do |t|
      t.uuid :organization_id
      t.string :github_uid
      t.string :github_username

      t.timestamps null: false
    end

    add_index :members, :github_uid
    add_index :members, :organization_id
  end
end
