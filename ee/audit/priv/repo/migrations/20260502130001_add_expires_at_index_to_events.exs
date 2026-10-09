defmodule Audit.Repo.Migrations.AddExpiresAtIndexToEvents do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:events, [:expires_at],
        concurrently: true,
        where: "expires_at IS NOT NULL"
      )
    )
  end
end
