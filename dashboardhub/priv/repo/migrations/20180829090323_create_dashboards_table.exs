defmodule Dashboardhub.Repo.Migrations.CreateDashboardsTable do
  use Ecto.Migration

  def change do
    create table(:dashboards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id
      add :name, :string
      add :content, :map

      timestamps()
    end

    create index(:dashboards, [:name])
    create index(:dashboards, [:org_id])
    create unique_index(:dashboards, [:org_id, :name], name: :unique_names_in_organization)
  end
end
