defmodule Audit.Repo.Migrations.AddOrgIdStreamedTimestampIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists(index(:events, [:org_id, :streamed, :timestamp], concurrently: true))
  end

  def down do
    drop_if_exists(index(:events, [:org_id, :streamed, :timestamp], concurrently: true))
  end
end
