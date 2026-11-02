defmodule Projecthub.Repo.Migrations.AddPullRequestCommitToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :pull_request_commit, :string, default: "merge_commit", null: false
    end
  end
end
