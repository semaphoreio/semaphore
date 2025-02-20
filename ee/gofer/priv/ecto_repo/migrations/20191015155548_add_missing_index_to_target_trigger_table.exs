defmodule Gofer.EctoRepo.Migrations.AddMissingIndexToTargetTriggerTable do
  use Ecto.Migration

  @disable_migration_lock true
  @disable_ddl_transaction true

  def change do
    create(index(:target_triggers, [:switch_id, :target_name], concurrently: true))
  end
end
