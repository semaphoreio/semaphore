class IndexJobStopRequestOnState < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_index "job_stop_requests", ["state"], name: "index_job_stop_requests_on_state", where: "state = 'pending'", using: :btree, algorithm: :concurrently
  end
end
