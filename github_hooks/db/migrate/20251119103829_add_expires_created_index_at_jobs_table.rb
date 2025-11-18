class AddExpiresCreatedIndexAtJobsTable < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :jobs,
              %i[expires_at created_at],
              name: "index_jobs_on_expires_created_not_null",
              algorithm: :concurrently,
              where: "expires_at IS NOT NULL",
              if_not_exists: true
  end
end
