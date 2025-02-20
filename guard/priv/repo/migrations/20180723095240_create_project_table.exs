defmodule Guard.Repo.Migrations.CreateProjectTable do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id
      add :repo_name, :string
      add :org_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create index(:projects, [:project_id])
  end
end
