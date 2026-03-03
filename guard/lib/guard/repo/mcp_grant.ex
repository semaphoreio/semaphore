defmodule Guard.Repo.McpGrant do
  @moduledoc """
  Ecto schema for MCP grants.
  """

  use Guard.Repo.Schema

  alias Guard.Repo.{McpGrantOrgGrant, McpGrantProjectGrant, RbacUser}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_grants" do
    field(:client_id, :string)
    field(:client_name, :string)
    field(:tool_scopes, {:array, :string}, default: [])
    field(:expires_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)
    field(:last_used_at, :utc_datetime)

    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)
    has_many(:org_grants, McpGrantOrgGrant, foreign_key: :grant_id)
    has_many(:project_grants, McpGrantProjectGrant, foreign_key: :grant_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :user_id,
      :client_id,
      :client_name,
      :tool_scopes,
      :expires_at,
      :revoked_at,
      :last_used_at
    ])
    |> validate_required([:user_id, :client_id])
    |> foreign_key_constraint(:user_id)
  end
end
