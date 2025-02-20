defmodule Guard.FrontRepo.Migrations.AddGithubUsernameToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :github_username, :string
    end
  end
end
