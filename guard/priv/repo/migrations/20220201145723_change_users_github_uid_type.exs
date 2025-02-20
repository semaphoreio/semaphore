defmodule Guard.Repo.Migrations.ChangeUsersGithubUidType do
  use Ecto.Migration

  def change do
    alter table("users") do
      modify :github_uid, :string, from: :integer
    end
  end
end
