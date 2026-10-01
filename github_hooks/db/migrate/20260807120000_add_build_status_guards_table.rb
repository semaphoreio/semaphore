class AddBuildStatusGuardsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :build_status_guards,
                 primary_key: [:repository_id, :commit_sha, :context, :source_id] do |t|
      t.uuid :repository_id, null: false
      t.text :commit_sha, null: false
      t.text :context, null: false
      t.text :source_id, null: false
      t.string :last_state, null: true
      t.timestamptz :claimed_at, null: true
      t.timestamptz :updated_at, null: false

      t.index :updated_at, name: "build_status_guards_updated_at_index"
    end
  end
end
