defmodule Projecthub.Repo.Migrations.AddPrFieldsToProjects do
  use Ecto.Migration

  def change do
		alter table("projects") do
			add :build_tag, :boolean
			add :build_branch, :boolean
			add :build_pr, :boolean
			add :build_forked_pr, :boolean
			add :allowed_secrets, :string
		end
  end
end
