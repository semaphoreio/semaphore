defmodule Audit.Repo.Migrations.AddTimestampIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(index(:events, [:org_id, :timestamp, :streamed], concurrently: true))
  end
end
