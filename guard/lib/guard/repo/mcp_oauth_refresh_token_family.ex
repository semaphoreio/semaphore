defmodule Guard.Repo.McpOAuthRefreshTokenFamily do
  @moduledoc """
  The refresh tokens rotated from one MCP OAuth authorization code. Every
  rotation locks the family, and revoking it revokes all of its tokens.
  """

  use Guard.Repo.Schema
  alias Guard.Repo.RbacUser

  @type t :: %__MODULE__{}

  schema "mcp_oauth_refresh_token_families" do
    field(:client_id, :string)
    field(:scope, :string)
    field(:expires_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)

    belongs_to(:user, RbacUser)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end
end
