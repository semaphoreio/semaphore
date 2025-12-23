defmodule Guard.Repo.McpGrant do
  use Guard.Repo.Schema
  import Ecto.Changeset
  alias Guard.Repo.{RbacUser, McpGrantOrg, McpGrantProject}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Valid tool scopes for MCP OAuth
  @valid_tool_scopes ~w(
    organizations:list
    projects:list
    projects:search
    workflows:search
    workflows:run
    workflows:rerun
    pipelines:list
    pipeline:jobs
    jobs:describe
    jobs:logs
    test_results:get
  )

  schema "mcp_grants" do
    belongs_to(:user, RbacUser, type: :binary_id, foreign_key: :user_id)
    field(:client_id, :string)
    field(:client_name, :string)
    field(:tool_scopes, {:array, :string})
    field(:expires_at, :utc_datetime)
    field(:revoked_at, :utc_datetime)
    field(:last_used_at, :utc_datetime)
    field(:created_by_ip, :string)
    field(:user_agent, :string)

    has_many(:org_grants, McpGrantOrg, foreign_key: :grant_id, on_delete: :delete_all)
    has_many(:project_grants, McpGrantProject, foreign_key: :grant_id, on_delete: :delete_all)

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
      :last_used_at,
      :created_by_ip,
      :user_agent
    ])
    |> validate_required([:user_id, :client_id])
    |> validate_tool_scopes()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_tool_scopes(changeset) do
    case get_change(changeset, :tool_scopes) do
      nil ->
        changeset

      scopes when is_list(scopes) ->
        invalid = scopes -- @valid_tool_scopes

        if Enum.empty?(invalid) do
          changeset
        else
          add_error(changeset, :tool_scopes, "contains invalid scopes: #{inspect(invalid)}")
        end
    end
  end

  def valid_tool_scopes, do: @valid_tool_scopes
end
