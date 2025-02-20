defmodule Audit.Repo.Migrations.AddIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(index(:events, [:org_id, :streamed], concurrently: true))
    drop_if_exists(index(:events, [:org_id], concurrently: true))
  end
end
