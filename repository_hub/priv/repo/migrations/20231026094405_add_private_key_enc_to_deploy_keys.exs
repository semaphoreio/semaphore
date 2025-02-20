defmodule RepositoryHub.Repo.Migrations.AddPrivateKeyEncToDeployKeys do
  use Ecto.Migration

  def change do
    alter table("deploy_keys") do
      add(:private_key_enc, :bytea, default: nil)
    end
  end
end
