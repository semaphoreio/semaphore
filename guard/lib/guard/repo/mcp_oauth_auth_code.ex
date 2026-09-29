defmodule Guard.Repo.McpOAuthAuthCode do
  @moduledoc """
  Ecto schema for MCP OAuth authorization codes.
  Single-use, short-lived codes exchanged for access tokens.
  """

  use Guard.Repo.Schema
  alias Guard.Repo.RbacUser

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_oauth_auth_codes" do
    field(:code, :string)
    field(:client_id, :string)
    field(:redirect_uri, :string)
    field(:code_challenge, :string)
    field(:expires_at, :utc_datetime)
    field(:used_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(auth_code, attrs) do
    auth_code
    |> cast(attrs, [
      :code,
      :client_id,
      :user_id,
      :redirect_uri,
      :code_challenge,
      :expires_at,
      :used_at
    ])
    |> validate_required([
      :code,
      :client_id,
      :user_id,
      :redirect_uri,
      :code_challenge,
      :expires_at
    ])
    |> unique_constraint(:code)
    |> foreign_key_constraint(:user_id)
  end
end
