class AddJobsUnfinishedBuildIdIndex < ActiveRecord::Migration[6.1]
  # Serves zebra's task finisher: "does this task still have unfinished
  # jobs?" is one probe into this index instead of a walk over every job of
  # the task. The index only holds jobs that are not finished, so it stays
  # small.
  #
  # A concurrent build that is interrupted leaves an INVALID index behind, and
  # if_not_exists then skips it on a later run. After deploying, check
  #   SELECT indisvalid FROM pg_index
  #   WHERE indexrelid = 'index_jobs_on_build_id_unfinished'::regclass;
  # If it is false, DROP INDEX CONCURRENTLY index_jobs_on_build_id_unfinished and
  # recreate it by hand with the same CREATE INDEX CONCURRENTLY statement.
  # Running this migration again is a no-op once its version is recorded.
  disable_ddl_transaction!

  def change
    add_index :jobs,
              :build_id,
              name: "index_jobs_on_build_id_unfinished",
              algorithm: :concurrently,
              where: "aasm_state <> 'finished'",
              if_not_exists: true
  end
end
