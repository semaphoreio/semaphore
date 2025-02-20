defmodule Rbac.FrontRepo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string
      add :name, :string
      add :authentication_token, :string
      add :blocked_at, :utc_datetime
      add :salt, :string
      add :remember_created_at, :utc_datetime
      add :idempotency_token, :string
      add :single_org_user, :boolean
      add :creation_source, :string
      add :org_id, :uuid
      add :deactivated, :boolean
      add :deactivated_at, :utc_datetime
      add :visited_at, :utc_datetime
      add :company, :string

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end

    create unique_index(:users, :authentication_token, name: :index_users_on_authentication_token)
    create unique_index(:users, :email, name: :index_users_on_email)
    create unique_index(:users, :idempotency_token, name: "users_idempotency_token_index", where: "idempotency_token IS NOT NULL")

  end
end
