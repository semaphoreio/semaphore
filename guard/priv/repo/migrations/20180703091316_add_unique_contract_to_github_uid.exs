defmodule Guard.Repo.Migrations.AddUniqueContractToGithubUid do
  use Ecto.Migration

  def change do
    create unique_index(:collaborators, [:project_id, :github_uid], name: :unique_githubber_in_project)
  end
end
