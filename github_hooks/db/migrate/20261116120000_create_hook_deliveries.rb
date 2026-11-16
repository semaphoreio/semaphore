class CreateHookDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :hook_deliveries, :id => false, :if_not_exists => true do |t|
      t.uuid :workflow_id, :primary_key => true, :null => false
      t.integer :retries, :null => false, :default => 0
      t.integer :stale_attempts, :null => false, :default => 0
      t.string :job_id, :null => false
      t.timestamptz :next_attempt_at, :null => false
      t.timestamptz :started_at
      t.integer :interrupted_runs, :null => false, :default => 0
      t.timestamptz :created_at, :null => false
      t.timestamptz :updated_at, :null => false
    end

    add_index :hook_deliveries, :next_attempt_at, :if_not_exists => true
  end
end
