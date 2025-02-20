defmodule Projecthub.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string
      add :slug, :string
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
      add :creator_id, :binary_id
      add :organization_id, :binary_id
      add :cache_id, :binary_id
      add :description, :string, default: "", null: false
    end

    create index(:projects, [:creator_id], name: "index_projects_on_creator_id")
    create index(:projects, [:organization_id], name: "index_projects_on_organization_id")
    create index(:projects, [:organization_id, :name], name: "index_projects_on_organization_id_and_name")
    create index(:projects, [:slug], name: "index_projects_on_slug")
  end
end
