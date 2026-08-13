# Mirrors repository_hub/priv/repo/migrations/20260807120000_add_build_status_guards_table.exs.
# The front schema is migrated by this app in production, while repository_hub
# (which owns the table at runtime) migrates its own standalone databases in
# dev and test — same version number, so whichever ledger runs first wins and
# the other skips it, as with 20240507111200_add_hook_secret_enc_to_repositories.
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
