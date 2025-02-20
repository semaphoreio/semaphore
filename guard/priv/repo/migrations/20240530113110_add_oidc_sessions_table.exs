defmodule Guard.Repo.Migrations.AddOIDCSessionsTable do
  use Ecto.Migration

  def change do
    create table(:oidc_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:rbac_users, on_delete: :delete_all)
      add :refresh_token_enc, :bytea, null: true
      add :expires_at, :utc_datetime_usec, null: true
      
      timestamps(type: :utc_datetime_usec)
    end
  end
end
