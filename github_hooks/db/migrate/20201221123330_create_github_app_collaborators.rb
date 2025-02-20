class CreateGithubAppCollaborators < ActiveRecord::Migration[5.1]
  def change
    create_table :github_app_collaborators, id: :uuid, default: -> { "uuid_generate_v4()" } do |t|
      t.string :r_name, null: false
      t.bigint :c_id, null: false
      t.string :c_name, null: false
      t.bigint :installation_id, null: false
    end

    add_index "github_app_collaborators", ["c_id"], using: :btree
    add_index "github_app_collaborators", ["r_name"], using: :btree
    add_index "github_app_collaborators", ["installation_id"], using: :btree
  end
end
