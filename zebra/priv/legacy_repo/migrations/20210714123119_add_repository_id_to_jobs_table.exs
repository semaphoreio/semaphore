defmodule Zebra.LegacyRepo.Migrations.AddRepositoryIdToJobsTable do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :repository_id, :uuid
    end
  end
end
