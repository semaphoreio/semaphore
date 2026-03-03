defmodule Guard.Repo.McpGrantOrgGrant do
  @moduledoc """
  Ecto schema for organization grants attached to an MCP grant.
  """

  use Guard.Repo.Schema

  alias Guard.Repo.McpGrant

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_grant_org_grants" do
    field(:org_id, :binary_id)
    field(:org_name, :string)
    field(:can_view, :boolean, default: false)
    field(:can_run_workflows, :boolean, default: false)

    belongs_to(:grant, McpGrant, type: :binary_id, foreign_key: :grant_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(org_grant, attrs) do
    org_grant
    |> cast(attrs, [:grant_id, :org_id, :org_name, :can_view, :can_run_workflows])
    |> validate_required([:grant_id, :org_id])
    |> unique_constraint([:grant_id, :org_id])
    |> foreign_key_constraint(:grant_id)
  end
end
