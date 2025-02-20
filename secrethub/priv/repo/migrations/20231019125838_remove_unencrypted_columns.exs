defmodule Secrethub.Repo.Migrations.RemoveUnencryptedColumns do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      remove(:content)
      remove(:content_validated)
    end

    alter table(:project_level_secrets) do
      remove(:content)
    end

    alter table(:deployment_target_secrets) do
      remove(:content)
    end
  end
end
