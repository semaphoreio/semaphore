defmodule Projecthub.Repo.Migrations.AddCusotmPermissionsToProjectsTable do
  use Ecto.Migration

  def change do
		alter table("projects") do
			add :custom_permissions, :boolean, default: false, null: false
    end
  end
end
