defmodule Scheduler.PeriodicsRepo.Migrations.AddNotificationSkipFlagsToPeriodics do
  use Ecto.Migration

  def change do
    alter table(:periodics) do
      add(:skip_scheduled_run_notifications, :boolean, null: false, default: false)
      add(:skip_manual_run_notifications, :boolean, null: false, default: false)
    end
  end
end
