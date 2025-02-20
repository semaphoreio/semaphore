defmodule Projecthub.Repo.Migrations.RenameArtifactIdToArtifactStoreIdForProjects do
  use Ecto.Migration

  def change do
    rename table("projects"), :artifact_id, to: :artifact_store_id
  end
end
