defmodule Guard.Repo.McpOAuthClient do
  @moduledoc """
  Ecto schema for MCP OAuth clients (Dynamic Client Registration).
  """

  use Guard.Repo.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_oauth_clients" do
    field(:client_id, :string)
    field(:client_name, :string)
    field(:redirect_uris, {:array, :string})

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:client_id, :client_name, :redirect_uris])
    |> validate_required([:client_id, :redirect_uris])
    |> validate_length(:redirect_uris, min: 1)
    |> unique_constraint(:client_id)
  end
end
