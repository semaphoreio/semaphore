defmodule Projecthub.Repo.Migrations.AddPermissionsSetupToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :permissions_setup, :boolean
    end
  end
end
