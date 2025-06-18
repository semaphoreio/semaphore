defmodule Zebra.LegacyRepo.Migrations.AddStoppedByToJobStopRequests do
  use Ecto.Migration

  def change do
    alter table(:job_stop_requests) do
      add :stopped_by, :string
    end

    alter table(:jobs) do
      add :stopped_by, :string
    end
  end
end
