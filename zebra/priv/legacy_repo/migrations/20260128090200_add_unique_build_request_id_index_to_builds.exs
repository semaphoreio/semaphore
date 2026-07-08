defmodule Zebra.LegacyRepo.Migrations.AddUniqueBuildRequestIdIndexToBuilds do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create unique_index(:builds, [:build_request_id],
      name: "unique_builds_on_build_request_id_not_null",
      concurrently: true,
      where: "build_request_id IS NOT NULL"
    )
  end
end
