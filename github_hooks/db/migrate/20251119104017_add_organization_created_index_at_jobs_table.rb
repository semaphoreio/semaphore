class AddOrganizationCreatedIndexAtJobsTable < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :jobs,
              %i[organization_id created_at],
              name: "index_jobs_on_organization_created_expires_is_null",
              algorithm: :concurrently,
              where: "expires_at IS NULL",
              if_not_exists: true
  end
end
