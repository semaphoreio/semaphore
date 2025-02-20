defmodule Secrethub.Repo.Migrations.CreateSecretsTable do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id
      add :name, :string
      add :content, :map

      timestamps()
    end

    create index(:secrets, [:name])
    create index(:secrets, [:org_id])
  end
end
