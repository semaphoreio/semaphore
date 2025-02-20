defmodule Scheduler.PeriodicsRepo.Migrations.AddSuspendedFieldToPeriodicsTable do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add :suspended, :boolean, default: false
    end
  end
end
