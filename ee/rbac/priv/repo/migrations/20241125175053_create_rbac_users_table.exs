defmodule Rbac.Repo.Migrations.CreateRbacUsersTable do
  use Ecto.Migration

  def change do
    create table(:rbac_users, primary_key: false) do
      add :id, references(:subjects, on_delete: :delete_all), primary_key: true
      add :email, :string
      add :name, :string

      timestamps(default: fragment("now()"))
    end

    create unique_index(:rbac_users, :email)
  end
end
