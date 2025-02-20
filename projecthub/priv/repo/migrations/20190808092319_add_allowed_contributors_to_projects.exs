defmodule Projecthub.Repo.Migrations.AddAllowedContributorsToProjects do
  use Ecto.Migration

  def change do
		alter table("projects") do
			add :allowed_contributors, :string
		end
  end
end
