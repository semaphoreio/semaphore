defmodule RepositoryHub.Repo.Migrations.AddHookSecretEncToRepositories do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add(:hook_secret_enc, :bytea, default: nil)
    end
  end
end
