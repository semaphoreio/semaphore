defmodule RepositoryHub.Repo.Migrations.AddRepositoryIdToDeployKeys do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("deploy_keys") do
      add(:repository_id, :uuid)
    end
  end
end
