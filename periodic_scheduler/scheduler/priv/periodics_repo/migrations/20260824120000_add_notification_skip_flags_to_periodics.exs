defmodule Scheduler.PeriodicsRepo.Migrations.AddNotificationSkipFlagsToPeriodics do
  use Ecto.Migration

  # Idempotent on purpose: cloud environments don't run migrations on container
  # start, so these columns may already have been applied by hand.
  def up do
    alter table(:periodics) do
      add_if_not_exists(:skip_scheduled_run_notifications, :boolean, null: false, default: false)
      add_if_not_exists(:skip_manual_run_notifications, :boolean, null: false, default: false)
    end
  end

  def down do
    alter table(:periodics) do
      remove_if_exists(:skip_scheduled_run_notifications, :boolean)
      remove_if_exists(:skip_manual_run_notifications, :boolean)
    end
  end
end
