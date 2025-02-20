defmodule Scheduler.PeriodicsRepo.Migrations.AddRecurringFlagAndParametersToPeriodicsTable do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add :recurring, :boolean, null: false, default: true
      add :parameters, :map
    end

    alter table(:periodics_triggers) do
      add :recurring, :boolean, null: false, default: true
      add :parameter_values, :map
    end
  end
end
