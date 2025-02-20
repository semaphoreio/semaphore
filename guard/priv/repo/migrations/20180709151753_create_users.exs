defmodule Guard.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :github_uid, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create index("users", :user_id, unique: true)
  end
end
