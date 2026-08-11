defmodule Guard.Repo.Migrations.CreateMcpOauthClients do
  use Ecto.Migration

  def change do
    create table(:mcp_oauth_clients, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :client_id, :string, null: false
      add :client_name, :string
      add :redirect_uris, {:array, :string}, default: []

      timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
    end

    create unique_index(:mcp_oauth_clients, [:client_id])
  end
end
