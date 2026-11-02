defmodule Zebra.LegacyRepo.Migrations.AddOriginalJobIdToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :original_job_id, :binary_id, if_not_exists: true
    end
  end
end
