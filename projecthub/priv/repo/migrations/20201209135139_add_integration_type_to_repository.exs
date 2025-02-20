defmodule Projecthub.Repo.Migrations.AddIntegrationTypeToRepository do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :integration_type, :string
    end
  end
end
