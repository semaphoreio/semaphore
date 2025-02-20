defmodule Guard.Repo.Migrations.AddGithubEmailToCollaborators do
  use Ecto.Migration

  def change do
    alter table(:collaborators) do
      add :github_email, :string
    end
  end
end
