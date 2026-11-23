defmodule Guard.Repo.McpOAuthRefreshToken do
  @moduledoc "An MCP OAuth refresh token, stored by its SHA-256."

  use Guard.Repo.Schema
  alias Guard.Repo.McpOAuthRefreshTokenFamily

  @type t :: %__MODULE__{}

  schema "mcp_oauth_refresh_tokens" do
    field(:token_hash, :string)
    field(:expires_at, :utc_datetime)
    field(:used_at, :utc_datetime)

    belongs_to(:family, McpOAuthRefreshTokenFamily)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end
end
