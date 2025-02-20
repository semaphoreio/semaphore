defmodule Scheduler.PeriodicsRepo.Migrations.AddCompositeIndexToPeriodicsTriggersTable do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:periodics_triggers, ["periodic_id", "triggered_at DESC NULLS LAST"],
                  concurrently: true)
  end
end
