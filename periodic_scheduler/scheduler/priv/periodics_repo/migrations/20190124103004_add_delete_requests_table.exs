defmodule Scheduler.PeriodicsRepo.Migrations.AddDeleteRequestsTable do
  use Ecto.Migration

  def change do
    create table(:delete_requests) do
      add :periodic_id, :string, default: ""
      add :periodic_name, :string, default: ""
      add :organization_id, :string, default: ""
      add :requester, :string, null: false

      timestamps()
    end
  end
end
