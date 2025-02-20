defmodule Projecthub.Repo.Migrations.AddDockerRegistryIdToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:docker_registry_id, :binary_id)
    end
  end
end
