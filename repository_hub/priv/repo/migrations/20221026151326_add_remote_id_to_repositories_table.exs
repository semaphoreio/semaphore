defmodule RepositoryHub.Repo.Migrations.AddRemoteIdToRepositoriesTable do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add(:remote_id, :string)
    end
  end
end
