defmodule RepositoryHub.Repo.Migrations.AddDefaultBranchToRepositoriesTable do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add(:default_branch, :string)
    end
  end
end
