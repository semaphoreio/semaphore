defmodule Zebra.LegacyRepo.Migrations.AddExpiresCreatedIndexAtJobsTable do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create index(:jobs, [:expires_at, :created_at],
      name: "index_jobs_on_expires_created_not_null",
      concurrently: true,
      where: "expires_at IS NOT NULL",
      if_not_exists: true
    )
  end
end
