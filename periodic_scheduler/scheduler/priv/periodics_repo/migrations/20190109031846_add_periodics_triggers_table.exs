defmodule Scheduler.PeriodicsRepo.Migrations.AddPeriodicsTriggersTable do
  use Ecto.Migration

  def change do
    create table(:periodics_triggers) do
      add :periodic_id, references(:periodics, type: :uuid, on_delete: :delete_all), null: false
      add :triggered_at,            :utc_datetime_usec
      add :project_id,              :string
      add :branch,                  :string
      add :pipeline_file,           :string
      add :scheduling_status,       :string
      add :scheduled_workflow_id,   :string, default: ""
      add :scheduled_at,            :utc_datetime_usec
      add :error_description,       :string, default: ""

      timestamps()
    end
  end
end
