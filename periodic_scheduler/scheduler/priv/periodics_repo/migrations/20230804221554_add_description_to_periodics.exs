defmodule Scheduler.PeriodicsRepo.Migrations.AddDescriptionToPeriodics do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add :description, :text
    end
  end
end
