class AddJobsOrganizationIdCreatedAtExpiringIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :jobs,
              %i[organization_id created_at],
              name: "index_jobs_on_organization_id_and_created_at_expiring",
              algorithm: :concurrently,
              where: "expires_at IS NOT NULL",
              if_not_exists: true
  end
end
