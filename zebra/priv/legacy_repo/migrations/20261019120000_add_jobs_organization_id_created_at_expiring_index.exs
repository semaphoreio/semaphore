defmodule Zebra.LegacyRepo.Migrations.AddJobsOrganizationIdCreatedAtExpiringIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(
      index(
        :jobs,
        [:organization_id, :created_at],
        name: :index_jobs_on_organization_id_and_created_at_expiring,
        where: "expires_at IS NOT NULL",
        concurrently: true
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :jobs,
        [:organization_id, :created_at],
        name: :index_jobs_on_organization_id_and_created_at_expiring,
        concurrently: true
      )
    )
  end
end
