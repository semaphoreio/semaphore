defmodule Guard.Repo.Migrations.AddPermissionsToCollaborators do
  use Ecto.Migration

  def change do
    alter table(:collaborators) do
      add :admin, :boolean, default: false, null: false
      add :push, :boolean, default: false, null: false
      add :pull, :boolean, default: false, null: false
    end
  end
end
