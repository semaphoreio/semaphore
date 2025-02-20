defmodule Projecthub.Repo.Migrations.AddCommitStatusToRepositories do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :commit_status, :map
    end
  end
end
