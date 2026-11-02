class AddOriginalJobIdIndexToJobs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :jobs,
              :original_job_id,
              name: "index_jobs_on_original_job_id_not_null",
              algorithm: :concurrently,
              where: "original_job_id IS NOT NULL",
              if_not_exists: true
  end
end
