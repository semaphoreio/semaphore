defmodule Scheduler.PeriodicsRepo.Migrations.RenameBranchToReference do
  use Ecto.Migration

  def change do
    rename(table(:periodics), :branch, to: :reference)
    rename(table(:periodics_triggers), :branch, to: :reference)
  end
end
