defmodule Guard.Repo.Migrations.ChangeCollaboratorsGithubUidTypeBack do
  use Ecto.Migration

  def change do
    alter table("collaborators") do
      modify :github_uid, :string, from: :integer
    end
  end
end
