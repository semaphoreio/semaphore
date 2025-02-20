defmodule Rbac.Repo.Migrations.CreateOidcUsersTable do
  use Ecto.Migration

  def change do
    create table(:oidc_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:rbac_users, on_delete: :delete_all)
      add :oidc_user_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:oidc_users, [:user_id])
    create index(:oidc_users, [:oidc_user_id], unique: true)
  end
end
