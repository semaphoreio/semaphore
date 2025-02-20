defmodule Guard.Repo.Migrations.CreateUniqueIndexProjectsProjectId do
  use Ecto.Migration

  def change do
    drop index(:projects, [:project_id])
    create unique_index(:projects, [:project_id])
  end
end
