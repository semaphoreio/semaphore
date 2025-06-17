defmodule Projecthub.Repo.Migrations.AddBuildDraftPrForProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :build_draft_pr, :boolean, default: true, null: false
    end
  end
end
