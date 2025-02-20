defmodule Zebra.Repo.Migrations.AddProjectIdToJobs do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      add :project_id, :binary_id
    end
  end
end
