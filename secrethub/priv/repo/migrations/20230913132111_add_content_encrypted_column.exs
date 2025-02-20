defmodule Secrethub.Repo.Migrations.AddContentEncryptedColumn do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      add :content_encrypted, :bytea, default: nil
    end

    alter table(:deployment_target_secrets) do
      add :content_encrypted, :bytea, default: nil
    end

    alter table(:project_level_secrets) do
      add :content_encrypted, :bytea, default: nil
    end
  end
end
