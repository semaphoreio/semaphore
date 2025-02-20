defmodule Projecthub.Repo.Migrations.AddWhitelistToRepositories do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :whitelist, :map
    end
  end
end
