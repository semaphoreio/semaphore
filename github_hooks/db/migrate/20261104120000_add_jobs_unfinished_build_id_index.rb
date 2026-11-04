class AddJobsUnfinishedBuildIdIndex < ActiveRecord::Migration[6.1]
  # Serves zebra's task finisher: "does this task still have unfinished
  # jobs?" is one probe into this index instead of a walk over every job of
  # the task. The index only holds jobs that are not finished, so it stays
  # small.
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
