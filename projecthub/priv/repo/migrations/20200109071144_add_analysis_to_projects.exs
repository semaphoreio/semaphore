defmodule Projecthub.Repo.Migrations.AddAnalysisToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :analysis, :map
    end
  end
end
