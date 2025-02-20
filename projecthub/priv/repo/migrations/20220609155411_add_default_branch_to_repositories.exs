defmodule Projecthub.Repo.Migrations.AddDefaultBranchToRepositories do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :default_branch, :string
    end

  end
end
