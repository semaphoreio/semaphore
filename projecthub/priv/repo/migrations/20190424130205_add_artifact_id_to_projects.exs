defmodule Projecthub.Repo.Migrations.AddArtifactIdToProjects do
  use Ecto.Migration

  def change do
		alter table("projects") do
			add :artifact_id, :binary_id
		end
  end
end
