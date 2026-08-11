defmodule Scheduler.PeriodicsRepo.Migrations.AddCommitStatusToPeriodics do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add(:commit_status, :text, null: false, default: "follow_project")
    end
  end
end
