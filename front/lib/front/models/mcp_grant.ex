defmodule Front.Models.McpGrant do
  @moduledoc false

  require Logger

  alias InternalApi.McpGrant
  alias InternalApi.McpGrant.McpGrantService.Stub

  @grpc_timeout 30_000
  @grpc_invalid_argument 3
  @grpc_not_found 5
  @grpc_failed_precondition 9

  @spec describe_consent_challenge(String.t(), String.t()) ::
          {:ok, McpGrant.DescribeConsentChallengeResponse.t()} | {:error, term()}
  def describe_consent_challenge(challenge_id, user_id) do
    Watchman.benchmark("mcp_grant.describe_consent_challenge.duration", fn ->
      request =
        McpGrant.DescribeConsentChallengeRequest.new(
          challenge_id: challenge_id,
          user_id: user_id
        )

      with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           {:ok, response} <-
             Stub.describe_consent_challenge(channel, request, timeout: @grpc_timeout) do
        {:ok, response}
      else
        {:error, error} -> handle_rpc_error("describe_consent_challenge", error)
      end
    end)
  end

  @spec approve_consent_challenge(String.t(), String.t(), map()) ::
          {:ok, McpGrant.ApproveConsentChallengeResponse.t()} | {:error, term()}
  def approve_consent_challenge(challenge_id, user_id, selection) do
    Watchman.benchmark("mcp_grant.approve_consent_challenge.duration", fn ->
      request =
        McpGrant.ApproveConsentChallengeRequest.new(
          challenge_id: challenge_id,
          user_id: user_id,
          selection: build_selection(selection)
        )

      with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           {:ok, response} <-
             Stub.approve_consent_challenge(channel, request, timeout: @grpc_timeout) do
        {:ok, response}
      else
        {:error, error} -> handle_rpc_error("approve_consent_challenge", error)
      end
    end)
  end

  @spec deny_consent_challenge(String.t(), String.t()) ::
          {:ok, McpGrant.DenyConsentChallengeResponse.t()} | {:error, term()}
  def deny_consent_challenge(challenge_id, user_id) do
    Watchman.benchmark("mcp_grant.deny_consent_challenge.duration", fn ->
      request =
        McpGrant.DenyConsentChallengeRequest.new(
          challenge_id: challenge_id,
          user_id: user_id
        )

      with {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           {:ok, response} <-
             Stub.deny_consent_challenge(channel, request, timeout: @grpc_timeout) do
        {:ok, response}
      else
        {:error, error} -> handle_rpc_error("deny_consent_challenge", error)
      end
    end)
  end

  defp api_endpoint do
    Application.fetch_env!(:front, :guard_grpc_endpoint)
  end

  defp build_selection(selection) when is_map(selection) do
    tool_scopes = Map.get(selection, :tool_scopes, [])

    org_grants =
      selection
      |> Map.get(:org_grants, [])
      |> Enum.map(fn org_grant ->
        McpGrant.OrgGrantInput.new(
          org_id: org_grant.org_id,
          can_view: org_grant.can_view,
          can_run_workflows: org_grant.can_run_workflows
        )
      end)

    project_grants =
      selection
      |> Map.get(:project_grants, [])
      |> Enum.map(fn project_grant ->
        McpGrant.ProjectGrantInput.new(
          project_id: project_grant.project_id,
          org_id: project_grant.org_id,
          can_view: project_grant.can_view,
          can_run_workflows: project_grant.can_run_workflows,
          can_view_logs: project_grant.can_view_logs
        )
      end)

    McpGrant.GrantSelection.new(
      tool_scopes: tool_scopes,
      org_grants: org_grants,
      project_grants: project_grants
    )
  end

  defp build_selection(_), do: McpGrant.GrantSelection.new()

  defp handle_rpc_error(action, %GRPC.RPCError{status: status, message: message} = error) do
    Logger.warning("[McpGrant] #{action} failed: #{inspect(error)}")

    case status do
      @grpc_invalid_argument -> {:error, {:invalid_argument, message}}
      @grpc_not_found -> {:error, :not_found}
      @grpc_failed_precondition -> {:error, {:failed_precondition, message}}
      _ -> {:error, {:rpc_error, message}}
    end
  end

  defp handle_rpc_error(action, error) do
    Logger.warning("[McpGrant] #{action} failed: #{inspect(error)}")
    {:error, {:rpc_error, "MCP consent request failed"}}
  end
end
