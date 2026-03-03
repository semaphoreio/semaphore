defmodule Guard.Repo.McpGrantProjectGrant do
  @moduledoc """
  Ecto schema for project grants attached to an MCP grant.
  """

  use Guard.Repo.Schema

  alias Guard.Repo.McpGrant

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_grant_project_grants" do
    field(:project_id, :binary_id)
    field(:org_id, :binary_id)
    field(:project_name, :string)
    field(:can_view, :boolean, default: false)
    field(:can_run_workflows, :boolean, default: false)
    field(:can_view_logs, :boolean, default: false)

    belongs_to(:grant, McpGrant, type: :binary_id, foreign_key: :grant_id)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(project_grant, attrs) do
    project_grant
    |> cast(attrs, [
      :grant_id,
      :project_id,
      :org_id,
      :project_name,
      :can_view,
      :can_run_workflows,
      :can_view_logs
    ])
    |> validate_required([:grant_id, :project_id, :org_id])
    |> unique_constraint([:grant_id, :project_id])
    |> foreign_key_constraint(:grant_id)
  end
end
