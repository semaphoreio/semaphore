defmodule Rbac.FrontRepo.Migrations.CreateRepoHostAccounts do
  use Ecto.Migration

  def change do
    create table(:repo_host_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :login, :string
      add :github_uid, :string
      add :repo_host, :string
      add :token, :string
      add :user_id, :binary_id
      add :name, :string
      add :permission_scope, :string
      add :revoked, :boolean, default: false, null: false
      add :refresh_token, :string
      add :token_expires_at, :utc_datetime
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end
  end
end
