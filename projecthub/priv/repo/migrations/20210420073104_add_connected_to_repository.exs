defmodule Projecthub.Repo.Migrations.AddConnectedToRepository do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :connected, :boolean, null: false, default: true
    end
  end
end
