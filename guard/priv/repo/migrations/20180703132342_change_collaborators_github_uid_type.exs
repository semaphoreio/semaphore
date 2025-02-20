defmodule Guard.Repo.Migrations.ChangeCollaboratorsGithubUidType do
  use Ecto.Migration

  def change do
    alter table("collaborators") do
      modify :github_uid, :'integer USING CAST(github_uid AS integer)'
    end
  end
end
