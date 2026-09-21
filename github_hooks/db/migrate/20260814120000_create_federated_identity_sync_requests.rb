class CreateFederatedIdentitySyncRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :federated_identity_sync_requests, :id => false, :if_not_exists => true do |t|
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
              :name => "federated_identity_sync_requests_next_attempt_at_index",
              :if_not_exists => true
    add_index :federated_identity_sync_requests, [:repo_host, :uid],
              :name => "federated_identity_sync_requests_repo_host_uid_index",
              :if_not_exists => true
  end
end
