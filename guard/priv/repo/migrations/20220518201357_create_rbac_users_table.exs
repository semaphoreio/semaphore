defmodule Guard.Repo.Migrations.CreateRbacUsersTable do
  use Ecto.Migration

  def change do
    create table(:rbac_users, primary_key: false) do
      add :id, references(:subjects, on_delete: :delete_all), primary_key: true
    end
  end
end
