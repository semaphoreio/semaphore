defmodule Zebra.LegacyRepo.Migrations.AddUniqueBuildRequestIdIndexToBuilds do
  use Ecto.Migration
  @disable_migration_lock true
  @disable_ddl_transaction true

  # Mirrors the production index created by the Rails-side 2018 migration
  # (add_index "builds", ["build_request_id"], unique: true) so the test
  # schema raises on the same constraint name the changeset listens for.
  def change do
    create(
      unique_index(:builds, [:build_request_id],
        name: "index_build_request_ids_on_builds",
        concurrently: true
      )
    )
  end
end
