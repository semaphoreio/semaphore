defmodule Rbac.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :github_uid, :string
      add :provider, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:github_uid, :provider], name: :unique_githubber)
  end
end
