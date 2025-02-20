defmodule Scheduler.PeriodicsRepo.Migrations.AddPauseFieldsToPeriodicsTable do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add :paused,           :boolean
      add :pause_toggled_by, :string
      add :pause_toggled_at, :utc_datetime_usec
    end
  end
end
