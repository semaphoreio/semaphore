defmodule Secrethub.Repo.Migrations.AddDescription do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      add :description, :string, default: ""
    end

    alter table(:project_level_secrets) do
      add :description, :string, default: ""
    end
  end
end
