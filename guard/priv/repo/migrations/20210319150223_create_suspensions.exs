defmodule Guard.Repo.Migrations.CreateSuspensions do
  use Ecto.Migration

  def change do
    create table(:suspensions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create index(:suspensions, [:org_id])
  end
end
