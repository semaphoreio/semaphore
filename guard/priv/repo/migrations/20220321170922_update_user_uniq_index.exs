defmodule Guard.Repo.Migrations.UpdateUserUniqIndex do
  use Ecto.Migration

  def change do
    drop index(:users, [:user_id], name: :users_user_id_index)
    create unique_index(:users, [:github_uid, :provider], name: :unique_githubber)
  end
end
