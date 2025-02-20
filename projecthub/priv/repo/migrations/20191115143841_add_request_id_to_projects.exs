defmodule Projecthub.Repo.Migrations.AddRequestIdToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :request_id, :binary_id
    end

    create index(:projects, [:request_id], name: "index_projects_on_request_id", unique: true)
  end
end
