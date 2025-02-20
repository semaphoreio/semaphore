defmodule Guard.FrontRepo.Migrations.CreateOauthConnections do
  use Ecto.Migration

  def change do
    create table(:oauth_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string
      add :provider, :string
      add :github_uid, :string
      add :user_id, :binary_id

      timestamps(inserted_at: :created_at, updated_at: :updated_at)
    end
  end
end
