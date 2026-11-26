class CreateJobCleanupCursors < ActiveRecord::Migration[8.0]
  # Progress of zebra's FinishedJobCleaner over jobs, ordered by (finished_at, id).
  # One row per cleanup pass, so a restarted worker resumes where it stopped.
  def change
    create_table :job_cleanup_cursors, id: :text, primary_key: :name do |t|
      t.datetime :finished_at, null: false
      t.uuid :job_id, null: false
      t.datetime :updated_at, null: false
    end
  end
end
