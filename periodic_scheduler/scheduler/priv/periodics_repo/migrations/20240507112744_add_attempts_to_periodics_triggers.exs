defmodule Scheduler.PeriodicsRepo.Migrations.AddAttemptsToPeriodicsTriggers do
  use Ecto.Migration

  def change do
    alter table(:periodics_triggers) do
      add :attempts, :integer
    end
  end
end
