class CreateFederatedIdentitySyncRequests < ActiveRecord::Migration[8.0]
  # Mirrors the Ecto migrations of the same name in guard/priv/front_repo and
  # ee/rbac/priv/front_repo, which only run against the local/test databases.
  # This is the one that creates the table in a deployed front database.
  #
  # Column names and types must match Ecto's expectations exactly:
  # `inserted_at` (not Rails' `created_at`) because the schema declares
  # `timestamps(type: :utc_datetime)` and lease_due/1 orders by it, precision 0
  # because `:utc_datetime` maps to timestamp(0), and limit 255 because Ecto's
  # `:string` does. Verified identical to the Ecto-created table with \d.
  def change
    create_table :federated_identity_sync_requests, :id => false do |t|
      t.uuid :id, :primary_key => true, :null => false
      t.string :repo_host, :null => false, :limit => 255
      t.string :uid, :null => false, :limit => 255
      t.uuid :claiming_user_id, :null => false
      t.uuid :released_user_ids, :array => true, :null => false, :default => []
      t.string :login, :null => false, :limit => 255
      t.integer :attempts, :null => false, :default => 0
      t.text :last_error
      t.datetime :next_attempt_at, :null => false, :precision => 0
      t.datetime :inserted_at, :null => false, :precision => 0
      t.datetime :updated_at, :null => false, :precision => 0
    end

    add_index :federated_identity_sync_requests, :next_attempt_at,
              :name => "federated_identity_sync_requests_next_attempt_at_index"
    add_index :federated_identity_sync_requests, [:repo_host, :uid],
              :name => "federated_identity_sync_requests_repo_host_uid_index"
  end
end
