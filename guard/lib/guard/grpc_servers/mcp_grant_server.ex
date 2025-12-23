defmodule Guard.GrpcServers.McpGrantServer do
  use GRPC.Server, service: InternalApi.McpGrant.McpGrantService.Service

  require Logger

  import Guard.Utils, only: [grpc_error!: 2, validate_uuid!: 1]
  import Guard.GrpcServers.Utils, only: [observe_and_log: 3]

  alias Guard.McpGrant.Actions
  alias Google.Protobuf.Timestamp
  alias InternalApi.McpGrant, as: McpGrantPB

  @doc """
  Create a new MCP grant
  """
  @spec create(McpGrantPB.CreateRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.CreateResponse.t()
  def create(
        %McpGrantPB.CreateRequest{
          user_id: user_id,
          client_id: client_id,
          client_name: client_name,
          tool_scopes: tool_scopes,
          org_grants: org_grants,
          project_grants: project_grants,
          expires_at: expires_at
        },
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.create",
      %{user_id: user_id, client_id: client_id},
      fn ->
        validate_uuid!(user_id)

        if String.trim(client_id) == "" do
          grpc_error!(:invalid_argument, "Client ID cannot be empty")
        end

        params = %{
          user_id: user_id,
          client_id: String.trim(client_id),
          client_name: client_name,
          tool_scopes: tool_scopes || [],
          org_grants: Enum.map(org_grants || [], &map_org_grant_input/1),
          project_grants: Enum.map(project_grants || [], &map_project_grant_input/1),
          expires_at: parse_timestamp(expires_at)
        }

        case Actions.create(params) do
          {:ok, grant} ->
            McpGrantPB.CreateResponse.new(grant: map_grant(grant))

          {:error, reason} ->
            Logger.error("Failed to create MCP grant: #{inspect(reason)}")
            grpc_error!(:invalid_argument, "Failed to create MCP grant")
        end
      end
    )
  end

  @doc """
  List MCP grants for a user
  """
  @spec list(McpGrantPB.ListRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.ListResponse.t()
  def list(
        %McpGrantPB.ListRequest{
          user_id: user_id,
          page_size: page_size,
          page_token: page_token,
          include_revoked: include_revoked
        },
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.list",
      %{user_id: user_id, page_size: page_size, include_revoked: include_revoked},
      fn ->
        validate_uuid!(user_id)

        effective_page_size = if page_size > 0 and page_size <= 100, do: page_size, else: 20
        effective_page_token = if page_token == "", do: nil, else: page_token

        params = %{
          page_size: effective_page_size,
          page_token: effective_page_token,
          include_revoked: include_revoked || false
        }

        case Actions.list(user_id, params) do
          {:ok, %{grants: grants, next_page_token: next_token, total_count: count}} ->
            McpGrantPB.ListResponse.new(
              grants: Enum.map(grants, &map_grant/1),
              next_page_token: next_token || "",
              total_count: count
            )

          {:error, reason} ->
            Logger.error("Failed to list MCP grants for user #{user_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to list grants")
        end
      end
    )
  end

  @doc """
  Describe a single MCP grant
  """
  @spec describe(McpGrantPB.DescribeRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.DescribeResponse.t()
  def describe(%McpGrantPB.DescribeRequest{grant_id: grant_id}, _stream) do
    observe_and_log(
      "grpc.mcp_grant.describe",
      %{grant_id: grant_id},
      fn ->
        validate_uuid!(grant_id)

        case Actions.describe(grant_id) do
          {:ok, grant} ->
            McpGrantPB.DescribeResponse.new(grant: map_grant(grant))

          {:error, :not_found} ->
            grpc_error!(:not_found, "Grant #{grant_id} not found")

          {:error, reason} ->
            Logger.error("Failed to describe grant #{grant_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to describe grant")
        end
      end
    )
  end

  @doc """
  Update an MCP grant
  """
  @spec update(McpGrantPB.UpdateRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.UpdateResponse.t()
  def update(
        %McpGrantPB.UpdateRequest{
          grant_id: grant_id,
          user_id: user_id,
          tool_scopes: tool_scopes,
          org_grants: org_grants,
          project_grants: project_grants
        },
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.update",
      %{grant_id: grant_id, user_id: user_id},
      fn ->
        validate_uuid!(grant_id)
        validate_uuid!(user_id)

        params =
          %{}
          |> maybe_put(:tool_scopes, tool_scopes)
          |> maybe_put(
            :org_grants,
            org_grants,
            &Enum.map(&1, fn og -> map_org_grant_input(og) end)
          )
          |> maybe_put(
            :project_grants,
            project_grants,
            &Enum.map(&1, fn pg -> map_project_grant_input(pg) end)
          )

        case Actions.update(grant_id, user_id, params) do
          {:ok, grant} ->
            McpGrantPB.UpdateResponse.new(grant: map_grant(grant))

          {:error, :not_found} ->
            grpc_error!(:not_found, "Grant #{grant_id} not found")

          {:error, :unauthorized} ->
            grpc_error!(:permission_denied, "Cannot update another user's grant")

          {:error, reason} ->
            Logger.error("Failed to update grant #{grant_id}: #{inspect(reason)}")
            grpc_error!(:invalid_argument, "Failed to update grant")
        end
      end
    )
  end

  @doc """
  Delete an MCP grant
  """
  @spec delete(McpGrantPB.DeleteRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.DeleteResponse.t()
  def delete(%McpGrantPB.DeleteRequest{grant_id: grant_id, user_id: user_id}, _stream) do
    observe_and_log(
      "grpc.mcp_grant.delete",
      %{grant_id: grant_id, user_id: user_id},
      fn ->
        validate_uuid!(grant_id)
        validate_uuid!(user_id)

        case Actions.delete(grant_id, user_id) do
          {:ok, :deleted} ->
            McpGrantPB.DeleteResponse.new()

          {:error, :not_found} ->
            grpc_error!(:not_found, "Grant #{grant_id} not found")

          {:error, :unauthorized} ->
            grpc_error!(:permission_denied, "Cannot delete another user's grant")

          {:error, reason} ->
            Logger.error("Failed to delete grant #{grant_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to delete grant")
        end
      end
    )
  end

  @doc """
  Revoke an MCP grant
  """
  @spec revoke(McpGrantPB.RevokeRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.RevokeResponse.t()
  def revoke(%McpGrantPB.RevokeRequest{grant_id: grant_id, user_id: user_id}, _stream) do
    observe_and_log(
      "grpc.mcp_grant.revoke",
      %{grant_id: grant_id, user_id: user_id},
      fn ->
        validate_uuid!(grant_id)
        validate_uuid!(user_id)

        case Actions.revoke(grant_id, user_id) do
          {:ok, grant} ->
            McpGrantPB.RevokeResponse.new(grant: map_grant(grant))

          {:error, :not_found} ->
            grpc_error!(:not_found, "Grant #{grant_id} not found")

          {:error, :unauthorized} ->
            grpc_error!(:permission_denied, "Cannot revoke another user's grant")

          {:error, reason} ->
            Logger.error("Failed to revoke grant #{grant_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to revoke grant")
        end
      end
    )
  end

  @doc """
  Check organization access for a grant
  """
  @spec check_org_access(McpGrantPB.CheckOrgAccessRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.CheckOrgAccessResponse.t()
  def check_org_access(
        %McpGrantPB.CheckOrgAccessRequest{grant_id: grant_id, org_id: org_id},
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.check_org_access",
      %{grant_id: grant_id, org_id: org_id},
      fn ->
        case Actions.check_org_access(grant_id, org_id) do
          {:ok, access} ->
            McpGrantPB.CheckOrgAccessResponse.new(
              allowed: access.allowed,
              can_view: access.can_view,
              can_run_workflows: access.can_run_workflows
            )

          {:error, :not_found} ->
            McpGrantPB.CheckOrgAccessResponse.new(
              allowed: false,
              can_view: false,
              can_run_workflows: false
            )
        end
      end
    )
  end

  @doc """
  Check project access for a grant
  """
  @spec check_project_access(McpGrantPB.CheckProjectAccessRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.CheckProjectAccessResponse.t()
  def check_project_access(
        %McpGrantPB.CheckProjectAccessRequest{grant_id: grant_id, project_id: project_id},
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.check_project_access",
      %{grant_id: grant_id, project_id: project_id},
      fn ->
        case Actions.check_project_access(grant_id, project_id) do
          {:ok, access} ->
            McpGrantPB.CheckProjectAccessResponse.new(
              allowed: access.allowed,
              can_view: access.can_view,
              can_run_workflows: access.can_run_workflows,
              can_view_logs: access.can_view_logs
            )

          {:error, :not_found} ->
            McpGrantPB.CheckProjectAccessResponse.new(
              allowed: false,
              can_view: false,
              can_run_workflows: false,
              can_view_logs: false
            )
        end
      end
    )
  end

  @doc """
  Get grant with validity check
  """
  @spec get_grant(McpGrantPB.GetGrantRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.GetGrantResponse.t()
  def get_grant(%McpGrantPB.GetGrantRequest{grant_id: grant_id}, _stream) do
    observe_and_log(
      "grpc.mcp_grant.get_grant",
      %{grant_id: grant_id},
      fn ->
        validate_uuid!(grant_id)

        case Actions.describe(grant_id) do
          {:ok, grant} ->
            is_valid =
              is_nil(grant.revoked_at) and
                (is_nil(grant.expires_at) or
                   DateTime.compare(grant.expires_at, DateTime.utc_now()) == :gt)

            McpGrantPB.GetGrantResponse.new(grant: map_grant(grant), is_valid: is_valid)

          {:error, :not_found} ->
            grpc_error!(:not_found, "Grant #{grant_id} not found")

          {:error, reason} ->
            Logger.error("Failed to get grant #{grant_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to get grant")
        end
      end
    )
  end

  @doc """
  Find existing valid grant for a user and client.

  Used by Keycloak Required Action to check if grant selection can be skipped.
  """
  @spec find_existing_grant(McpGrantPB.FindExistingGrantRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrantPB.FindExistingGrantResponse.t()
  def find_existing_grant(
        %McpGrantPB.FindExistingGrantRequest{user_id: user_id, client_id: client_id},
        _stream
      ) do
    observe_and_log(
      "grpc.mcp_grant.find_existing_grant",
      %{user_id: user_id, client_id: client_id},
      fn ->
        # Don't validate UUID for user_id as it might come from Keycloak
        # Just validate it's not empty
        if String.trim(user_id) == "" or String.trim(client_id) == "" do
          McpGrantPB.FindExistingGrantResponse.new(grant: nil, found: false)
        else
          case Actions.find_existing_grant(user_id, client_id) do
            {:ok, grant} ->
              McpGrantPB.FindExistingGrantResponse.new(
                grant: map_grant(grant),
                found: true
              )

            {:error, _reason} ->
              # Not found or invalid params - return found: false
              McpGrantPB.FindExistingGrantResponse.new(grant: nil, found: false)
          end
        end
      end
    )
  end

  # Helper functions

  defp map_grant(grant) do
    McpGrantPB.McpGrant.new(
      id: grant.id,
      user_id: grant.user_id,
      client_id: grant.client_id,
      client_name: grant.client_name || "",
      tool_scopes: grant.tool_scopes || [],
      org_grants: Enum.map(grant.org_grants || [], &map_org_grant/1),
      project_grants: Enum.map(grant.project_grants || [], &map_project_grant/1),
      created_at: grpc_timestamp(grant.created_at),
      expires_at: grpc_timestamp(grant.expires_at),
      revoked_at: grpc_timestamp(grant.revoked_at),
      last_used_at: grpc_timestamp(grant.last_used_at)
    )
  end

  defp map_org_grant(og) do
    McpGrantPB.OrgGrant.new(
      org_id: og.org_id,
      org_name: og.org_name || "",
      can_view: og.can_view,
      can_run_workflows: og.can_run_workflows
    )
  end

  defp map_project_grant(pg) do
    McpGrantPB.ProjectGrant.new(
      project_id: pg.project_id,
      org_id: pg.org_id,
      project_name: pg.project_name || "",
      can_view: pg.can_view,
      can_run_workflows: pg.can_run_workflows,
      can_view_logs: pg.can_view_logs
    )
  end

  defp map_org_grant_input(ogi) do
    %{
      org_id: ogi.org_id,
      can_view: ogi.can_view,
      can_run_workflows: ogi.can_run_workflows
    }
  end

  defp map_project_grant_input(pgi) do
    %{
      project_id: pgi.project_id,
      org_id: pgi.org_id,
      can_view: pgi.can_view,
      can_run_workflows: pgi.can_run_workflows,
      can_view_logs: pgi.can_view_logs
    }
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(%Timestamp{seconds: seconds}) do
    DateTime.from_unix!(seconds, :second)
  end

  defp grpc_timestamp(nil), do: nil

  defp grpc_timestamp(%DateTime{} = value) do
    unix_timestamp = DateTime.to_unix(value, :second)
    Timestamp.new(seconds: unix_timestamp)
  end

  defp grpc_timestamp(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map

  defp maybe_put(map, key, value, transform_fn) when is_function(transform_fn, 1) do
    Map.put(map, key, transform_fn.(value))
  end

  defp maybe_put(map, key, value) do
    Map.put(map, key, value)
  end
end
