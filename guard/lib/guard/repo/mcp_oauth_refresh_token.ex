defmodule Guard.Repo.McpOAuthRefreshToken do
  @moduledoc """
  Ecto schema for MCP OAuth refresh tokens.

  Refresh tokens are single-use: every refresh rotates the token and marks the
  presented one used. All tokens descending from one authorization grant share a
  `family_id`, so re-presenting an already-used token (replay) can revoke the
  whole family at once. Only the sha256 hash of the token is stored.
  """

  use Guard.Repo.Schema
  alias Guard.Repo.RbacUser

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_oauth_refresh_tokens" do
    field(:token_hash, :string)
    field(:family_id, :binary_id)
    field(:client_id, :string)
    field(:expires_at, :utc_datetime)
    field(:used_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(refresh_token, attrs) do
    refresh_token
    |> cast(attrs, [
      :token_hash,
      :family_id,
      :client_id,
      :user_id,
      :expires_at,
      :used_at,
      :revoked_at
    ])
    |> validate_required([
      :token_hash,
      :family_id,
      :client_id,
      :user_id,
      :expires_at
    ])
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end
end
