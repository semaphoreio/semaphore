defmodule Zebra.LegacyRepo.Migrations.AddOrganizationCreatedIndexAtJobsTable do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:jobs, [:organization_id, :created_at],
      name: "index_jobs_on_organization_created_expires_is_null",
      concurrently: true,
      where: "expires_at IS NULL"
    )
  end
end
