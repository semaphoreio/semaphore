defmodule Scheduler.PeriodicsRepo.Migrations.AddRunNowRequesterIdToPeriodicTriggersTable do
  use Ecto.Migration

  def change do
    alter table(:periodics_triggers) do
      add :run_now_requester_id, :string
    end
  end
end
