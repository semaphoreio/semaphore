defmodule Guard.Repo.Migrations.AddProviderToProjectsTable do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :provider, :string
    end
  end
end
