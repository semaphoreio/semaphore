defmodule Guard.Repo.Migrations.AddRepositoryIdToProjectsTable do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :repository_id, :string
    end
  end
end
