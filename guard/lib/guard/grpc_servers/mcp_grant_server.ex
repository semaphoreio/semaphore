defmodule Guard.GrpcServers.McpGrantServer do
  use GRPC.Server, service: InternalApi.McpGrant.McpGrantService.Service

  require Logger

  import Guard.Utils, only: [grpc_error!: 2, timestamp_to_datetime: 2, valid_uuid?: 1]

  alias Guard.GrpcServers.Utils, as: GrpcUtils
  alias Guard.McpOAuth.Authorize
  alias Guard.Repo

  alias Guard.Store.{
    McpOAuthAuthCode,
    McpOAuthClient,
    McpOAuthConsentChallenge,
    Organization
  }

  alias Guard.Store.McpGrant, as: McpGrantStore
  alias InternalApi.McpGrant

  @auth_code_ttl_seconds 600
  @consent_ttl_seconds 600
  @default_grant_ttl_seconds 2_592_000

  @org_view_permission "organization.view"
  @org_run_permission "project.run"

  @project_view_permission "project.view"
  @project_run_permission "project.run"
  @project_log_permissions ["job.view", "project.view"]

  @spec create(McpGrant.CreateRequest.t(), GRPC.Server.Stream.t()) :: McpGrant.CreateResponse.t()
  def create(%McpGrant.CreateRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.create", request, fn ->
      validate_uuid!(request.user_id, :user_id)

      {:ok, expires_at} = timestamp_to_datetime(request.expires_at, nil)

      request
      |> create_request_to_attrs(expires_at)
      |> McpGrantStore.create()
      |> case do
        {:ok, grant} -> McpGrant.CreateResponse.new(grant: to_proto_grant(grant))
        {:error, reason} -> handle_changeset_error(reason)
      end
    end)
  end

  @spec list(McpGrant.ListRequest.t(), GRPC.Server.Stream.t()) :: McpGrant.ListResponse.t()
  def list(%McpGrant.ListRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.list", request, fn ->
      validate_uuid!(request.user_id, :user_id)

      {:ok, %{grants: grants, next_page_token: next_page_token}} =
        McpGrantStore.list_for_user(request.user_id, %{
          page_size: request.page_size,
          page_token: request.page_token,
          include_revoked: request.include_revoked
        })

      McpGrant.ListResponse.new(
        grants: Enum.map(grants, &to_proto_grant/1),
        next_page_token: next_page_token,
        total_count: length(grants)
      )
    end)
  end

  @spec describe(McpGrant.DescribeRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.DescribeResponse.t()
  def describe(%McpGrant.DescribeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.describe", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)

      case McpGrantStore.get(request.grant_id) do
        {:ok, grant} -> McpGrant.DescribeResponse.new(grant: to_proto_grant(grant))
        {:error, :not_found} -> grpc_error!(:not_found, "MCP grant not found")
      end
    end)
  end

  @spec update(McpGrant.UpdateRequest.t(), GRPC.Server.Stream.t()) :: McpGrant.UpdateResponse.t()
  def update(%McpGrant.UpdateRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.update", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)
      validate_uuid!(request.user_id, :user_id)

      with {:ok, grant} <- McpGrantStore.get_for_user(request.grant_id, request.user_id),
           {:ok, updated_grant} <- McpGrantStore.update(grant, update_request_to_attrs(request)) do
        McpGrant.UpdateResponse.new(grant: to_proto_grant(updated_grant))
      else
        {:error, :not_found} -> grpc_error!(:not_found, "MCP grant not found")
        {:error, reason} -> handle_changeset_error(reason)
      end
    end)
  end

  @spec delete(McpGrant.DeleteRequest.t(), GRPC.Server.Stream.t()) :: McpGrant.DeleteResponse.t()
  def delete(%McpGrant.DeleteRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.delete", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)
      validate_uuid!(request.user_id, :user_id)

      case McpGrantStore.delete_for_user(request.grant_id, request.user_id) do
        :ok -> McpGrant.DeleteResponse.new()
        {:error, :not_found} -> grpc_error!(:not_found, "MCP grant not found")
      end
    end)
  end

  @spec revoke(McpGrant.RevokeRequest.t(), GRPC.Server.Stream.t()) :: McpGrant.RevokeResponse.t()
  def revoke(%McpGrant.RevokeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.revoke", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)
      validate_uuid!(request.user_id, :user_id)

      case McpGrantStore.revoke_for_user(request.grant_id, request.user_id) do
        {:ok, grant} -> McpGrant.RevokeResponse.new(grant: to_proto_grant(grant))
        {:error, :not_found} -> grpc_error!(:not_found, "MCP grant not found")
        {:error, reason} -> handle_changeset_error(reason)
      end
    end)
  end

  @spec check_org_access(McpGrant.CheckOrgAccessRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.CheckOrgAccessResponse.t()
  def check_org_access(%McpGrant.CheckOrgAccessRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.check_org_access", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)

      case McpGrantStore.get(request.grant_id) do
        {:ok, grant} ->
          if McpGrantStore.valid?(grant) do
            access = McpGrantStore.check_org_access(grant, request.org_id)

            McpGrant.CheckOrgAccessResponse.new(
              allowed: access.allowed,
              can_view: access.can_view,
              can_run_workflows: access.can_run_workflows
            )
          else
            McpGrant.CheckOrgAccessResponse.new(
              allowed: false,
              can_view: false,
              can_run_workflows: false
            )
          end

        {:error, :not_found} ->
          McpGrant.CheckOrgAccessResponse.new(
            allowed: false,
            can_view: false,
            can_run_workflows: false
          )
      end
    end)
  end

  @spec check_project_access(McpGrant.CheckProjectAccessRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.CheckProjectAccessResponse.t()
  def check_project_access(%McpGrant.CheckProjectAccessRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.check_project_access", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)

      case McpGrantStore.get(request.grant_id) do
        {:ok, grant} ->
          if McpGrantStore.valid?(grant) do
            access = McpGrantStore.check_project_access(grant, request.project_id)

            McpGrant.CheckProjectAccessResponse.new(
              allowed: access.allowed,
              can_view: access.can_view,
              can_run_workflows: access.can_run_workflows,
              can_view_logs: access.can_view_logs
            )
          else
            McpGrant.CheckProjectAccessResponse.new(
              allowed: false,
              can_view: false,
              can_run_workflows: false,
              can_view_logs: false
            )
          end

        {:error, :not_found} ->
          McpGrant.CheckProjectAccessResponse.new(
            allowed: false,
            can_view: false,
            can_run_workflows: false,
            can_view_logs: false
          )
      end
    end)
  end

  @spec get_grant(McpGrant.GetGrantRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.GetGrantResponse.t()
  def get_grant(%McpGrant.GetGrantRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.get_grant", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)

      case McpGrantStore.get(request.grant_id) do
        {:ok, grant} ->
          McpGrant.GetGrantResponse.new(
            grant: to_proto_grant(grant),
            is_valid: McpGrantStore.valid?(grant)
          )

        {:error, :not_found} ->
          McpGrant.GetGrantResponse.new(is_valid: false)
      end
    end)
  end

  @spec find_existing_grant(McpGrant.FindExistingGrantRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.FindExistingGrantResponse.t()
  def find_existing_grant(%McpGrant.FindExistingGrantRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.find_existing_grant", request, fn ->
      validate_uuid!(request.user_id, :user_id)

      case McpGrantStore.find_existing_valid_grant(request.user_id, request.client_id) do
        {:ok, grant} ->
          McpGrant.FindExistingGrantResponse.new(grant: to_proto_grant(grant), found: true)

        {:error, :not_found} ->
          McpGrant.FindExistingGrantResponse.new(found: false)
      end
    end)
  end

  @spec create_consent_challenge(
          McpGrant.CreateConsentChallengeRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          McpGrant.CreateConsentChallengeResponse.t()
  def create_consent_challenge(%McpGrant.CreateConsentChallengeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.create_consent_challenge", request, fn ->
      validate_uuid!(request.user_id, :user_id)

      with {:ok, client} <- McpOAuthClient.find_by_client_id(request.client_id),
           :ok <- validate_redirect_uri(client, request.redirect_uri),
           :ok <- validate_code_challenge_method(request.code_challenge_method) do
        expires_at =
          DateTime.utc_now()
          |> DateTime.add(@consent_ttl_seconds, :second)
          |> DateTime.truncate(:second)

        attrs = %{
          user_id: request.user_id,
          client_id: request.client_id,
          client_name: request.client_name,
          redirect_uri: request.redirect_uri,
          code_challenge: request.code_challenge,
          code_challenge_method: request.code_challenge_method,
          state: request.state,
          requested_scope: request.requested_scope,
          expires_at: expires_at
        }

        case McpOAuthConsentChallenge.create(attrs) do
          {:ok, challenge} ->
            McpGrant.CreateConsentChallengeResponse.new(
              challenge_id: challenge.id,
              expires_at: to_proto_timestamp(challenge.expires_at)
            )

          {:error, reason} ->
            handle_changeset_error(reason)
        end
      else
        {:error, :not_found} -> grpc_error!(:invalid_argument, "Unknown client_id")
        {:error, reason} -> grpc_error!(:invalid_argument, reason)
      end
    end)
  end

  @spec describe_consent_challenge(
          McpGrant.DescribeConsentChallengeRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          McpGrant.DescribeConsentChallengeResponse.t()
  def describe_consent_challenge(%McpGrant.DescribeConsentChallengeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.describe_consent_challenge", request, fn ->
      validate_uuid!(request.challenge_id, :challenge_id)
      validate_uuid!(request.user_id, :user_id)

      with {:ok, challenge} <-
             McpOAuthConsentChallenge.get_active(request.challenge_id, request.user_id) do
        existing_grant =
          case McpGrantStore.find_existing_valid_grant(request.user_id, challenge.client_id) do
            {:ok, grant} -> grant
            {:error, :not_found} -> nil
          end

        selection = McpGrantStore.default_selection(existing_grant)
        {available_orgs, available_projects} = available_grants_for_user(request.user_id)

        McpGrant.DescribeConsentChallengeResponse.new(
          challenge: to_proto_challenge(challenge),
          found_existing_grant: not is_nil(existing_grant),
          existing_grant: if(existing_grant, do: to_proto_grant(existing_grant), else: nil),
          default_selection: to_proto_selection(selection),
          available_organizations: Enum.map(available_orgs, &to_proto_grantable_org/1),
          available_projects: Enum.map(available_projects, &to_proto_grantable_project/1)
        )
      else
        {:error, :not_found} -> grpc_error!(:not_found, "Consent challenge not found or expired")
      end
    end)
  end

  @spec approve_consent_challenge(
          McpGrant.ApproveConsentChallengeRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          McpGrant.ApproveConsentChallengeResponse.t()
  def approve_consent_challenge(%McpGrant.ApproveConsentChallengeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.approve_consent_challenge", request, fn ->
      validate_uuid!(request.challenge_id, :challenge_id)
      validate_uuid!(request.user_id, :user_id)

      case approve_challenge(request) do
        {:ok, payload} ->
          McpGrant.ApproveConsentChallengeResponse.new(
            grant_id: payload.grant_id,
            authorization_code: payload.authorization_code,
            redirect_uri: payload.redirect_uri,
            state: payload.state,
            redirect_url: payload.redirect_url,
            reused_existing_grant: payload.reused_existing_grant
          )

        {:error, :not_found} ->
          grpc_error!(:not_found, "Consent challenge not found or expired")

        {:error, reason} when is_binary(reason) ->
          grpc_error!(:failed_precondition, reason)

        {:error, reason} ->
          handle_changeset_error(reason)
      end
    end)
  end

  @spec deny_consent_challenge(McpGrant.DenyConsentChallengeRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.DenyConsentChallengeResponse.t()
  def deny_consent_challenge(%McpGrant.DenyConsentChallengeRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.deny_consent_challenge", request, fn ->
      validate_uuid!(request.challenge_id, :challenge_id)
      validate_uuid!(request.user_id, :user_id)

      case McpOAuthConsentChallenge.consume(request.challenge_id, request.user_id) do
        {:ok, challenge} ->
          error = if(request.error in [nil, ""], do: "access_denied", else: request.error)

          description =
            if(request.error_description in [nil, ""],
              do: "User denied access",
              else: request.error_description
            )

          redirect_url =
            Authorize.build_error_redirect(
              challenge.redirect_uri,
              error,
              description,
              challenge.state
            )

          McpGrant.DenyConsentChallengeResponse.new(
            redirect_uri: challenge.redirect_uri,
            state: challenge.state || "",
            redirect_url: redirect_url
          )

        {:error, :invalid_or_used} ->
          grpc_error!(:not_found, "Consent challenge not found or expired")
      end
    end)
  end

  @spec resolve_grant_for_auth(McpGrant.ResolveGrantForAuthRequest.t(), GRPC.Server.Stream.t()) ::
          McpGrant.ResolveGrantForAuthResponse.t()
  def resolve_grant_for_auth(%McpGrant.ResolveGrantForAuthRequest{} = request, _stream) do
    GrpcUtils.observe_and_log("grpc.mcp_grant.resolve_grant_for_auth", request, fn ->
      validate_uuid!(request.grant_id, :grant_id)
      validate_uuid!(request.user_id, :user_id)

      case McpGrantStore.get_for_user(request.grant_id, request.user_id) do
        {:ok, grant} ->
          if McpGrantStore.valid?(grant) do
            :ok = McpGrantStore.touch_last_used(grant.id)

            org_permissions =
              grant
              |> McpGrantStore.resolve_org_permissions()
              |> Enum.map(fn perms ->
                McpGrant.ResolvedOrgPermissions.new(
                  org_id: perms.org_id,
                  permissions: perms.permissions
                )
              end)

            project_permissions =
              grant
              |> McpGrantStore.resolve_project_permissions()
              |> Enum.map(fn perms ->
                McpGrant.ResolvedProjectPermissions.new(
                  project_id: perms.project_id,
                  org_id: perms.org_id,
                  permissions: perms.permissions
                )
              end)

            McpGrant.ResolveGrantForAuthResponse.new(
              valid: true,
              invalid_reason: "",
              grant: to_proto_grant(grant),
              tool_scopes: grant.tool_scopes,
              org_permissions: org_permissions,
              project_permissions: project_permissions
            )
          else
            McpGrant.ResolveGrantForAuthResponse.new(
              valid: false,
              invalid_reason: invalid_reason(grant),
              grant: to_proto_grant(grant)
            )
          end

        {:error, :not_found} ->
          McpGrant.ResolveGrantForAuthResponse.new(valid: false, invalid_reason: "not_found")
      end
    end)
  end

  defp create_request_to_attrs(request, expires_at) do
    %{
      user_id: request.user_id,
      client_id: request.client_id,
      client_name: request.client_name,
      tool_scopes: request.tool_scopes,
      org_grants: Enum.map(request.org_grants, &org_grant_input_to_attrs/1),
      project_grants: Enum.map(request.project_grants, &project_grant_input_to_attrs/1),
      expires_at: expires_at
    }
  end

  defp update_request_to_attrs(request) do
    %{
      tool_scopes: request.tool_scopes,
      org_grants: Enum.map(request.org_grants, &org_grant_input_to_attrs/1),
      project_grants: Enum.map(request.project_grants, &project_grant_input_to_attrs/1)
    }
  end

  defp approve_challenge(request) do
    Repo.transaction(fn ->
      with {:ok, challenge} <-
             McpOAuthConsentChallenge.consume(request.challenge_id, request.user_id),
           {:ok, grant} <-
             create_grant_from_selection(challenge, request.selection, request.user_id),
           {:ok, auth_code} <- create_auth_code(challenge, request.user_id, grant.id) do
        redirect_url =
          Authorize.build_success_redirect(
            challenge.redirect_uri,
            auth_code.code,
            challenge.state
          )

        %{
          grant_id: grant.id,
          authorization_code: auth_code.code,
          redirect_uri: challenge.redirect_uri,
          state: challenge.state || "",
          redirect_url: redirect_url,
          reused_existing_grant: false
        }
      else
        {:error, :invalid_or_used} -> Repo.rollback(:not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, payload} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_grant_from_selection(challenge, selection, user_id) do
    selection = normalize_selection(selection)

    with :ok <- validate_tool_scopes(challenge.requested_scope, selection.tool_scopes),
         :ok <- validate_selection_permissions(user_id, selection) do
      org_grants = enrich_org_grants(selection.org_grants)
      project_grants = enrich_project_grants(selection.project_grants)

      expires_at =
        DateTime.utc_now()
        |> DateTime.add(grant_ttl_seconds(), :second)
        |> DateTime.truncate(:second)

      attrs = %{
        user_id: user_id,
        client_id: challenge.client_id,
        client_name: challenge.client_name,
        tool_scopes: selection.tool_scopes,
        org_grants: org_grants,
        project_grants: project_grants,
        expires_at: expires_at
      }

      McpGrantStore.create(attrs)
    end
  end

  defp normalize_selection(nil), do: %{tool_scopes: [], org_grants: [], project_grants: []}

  defp normalize_selection(%McpGrant.GrantSelection{} = selection) do
    %{
      tool_scopes: selection.tool_scopes |> List.wrap() |> Enum.uniq(),
      org_grants: Enum.map(selection.org_grants || [], &org_grant_input_to_attrs/1),
      project_grants: Enum.map(selection.project_grants || [], &project_grant_input_to_attrs/1)
    }
  end

  defp normalize_selection(_), do: %{tool_scopes: [], org_grants: [], project_grants: []}

  defp validate_tool_scopes(requested_scope, tool_scopes) do
    requested_scopes = parse_scope(requested_scope)

    if Enum.all?(tool_scopes, fn scope -> scope in requested_scopes end) do
      :ok
    else
      {:error, "Requested tool scopes are not allowed"}
    end
  end

  defp validate_selection_permissions(user_id, selection) do
    {available_orgs, available_projects} = available_grants_for_user(user_id)

    available_orgs_by_id = Map.new(available_orgs, fn org -> {org.org_id, org} end)

    available_projects_by_id =
      Map.new(available_projects, fn project -> {project.project_id, project} end)

    with :ok <- validate_org_grants(selection.org_grants, available_orgs_by_id),
         :ok <- validate_project_grants(selection.project_grants, available_projects_by_id) do
      :ok
    end
  end

  defp validate_org_grants(org_grants, available_orgs_by_id) do
    org_grants
    |> Enum.reduce_while({:ok, MapSet.new()}, fn org_grant, {:ok, seen_org_ids} ->
      org_id = org_grant.org_id

      cond do
        MapSet.member?(seen_org_ids, org_id) ->
          {:halt, {:error, "Duplicate organization grant requested"}}

        not (org_grant.can_view or org_grant.can_run_workflows) ->
          {:halt, {:error, "Organization grant must include at least one permission"}}

        not Map.has_key?(available_orgs_by_id, org_id) ->
          {:halt, {:error, "Requested organization grant is not allowed"}}

        org_grant.can_view and not available_orgs_by_id[org_id].can_view ->
          {:halt, {:error, "Requested organization view permission is not allowed"}}

        org_grant.can_run_workflows and not available_orgs_by_id[org_id].can_run_workflows ->
          {:halt, {:error, "Requested organization run permission is not allowed"}}

        true ->
          {:cont, {:ok, MapSet.put(seen_org_ids, org_id)}}
      end
    end)
    |> case do
      {:ok, _seen_org_ids} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_project_grants(project_grants, available_projects_by_id) do
    project_grants
    |> Enum.reduce_while({:ok, MapSet.new()}, fn project_grant, {:ok, seen_project_ids} ->
      project_id = project_grant.project_id

      cond do
        MapSet.member?(seen_project_ids, project_id) ->
          {:halt, {:error, "Duplicate project grant requested"}}

        not (project_grant.can_view or project_grant.can_run_workflows or
                 project_grant.can_view_logs) ->
          {:halt, {:error, "Project grant must include at least one permission"}}

        not Map.has_key?(available_projects_by_id, project_id) ->
          {:halt, {:error, "Requested project grant is not allowed"}}

        project_grant.org_id != available_projects_by_id[project_id].org_id ->
          {:halt, {:error, "Requested project grant organization does not match"}}

        project_grant.can_view and not available_projects_by_id[project_id].can_view ->
          {:halt, {:error, "Requested project view permission is not allowed"}}

        project_grant.can_run_workflows and
            not available_projects_by_id[project_id].can_run_workflows ->
          {:halt, {:error, "Requested project run permission is not allowed"}}

        project_grant.can_view_logs and not available_projects_by_id[project_id].can_view_logs ->
          {:halt, {:error, "Requested project log permission is not allowed"}}

        true ->
          {:cont, {:ok, MapSet.put(seen_project_ids, project_id)}}
      end
    end)
    |> case do
      {:ok, _seen_project_ids} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_scope(scope) when is_binary(scope) do
    scope
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
  end

  defp parse_scope(_), do: []

  defp grant_ttl_seconds do
    case Application.get_env(:guard, :mcp_grant_ttl_seconds, @default_grant_ttl_seconds) do
      ttl when is_integer(ttl) and ttl > 0 -> ttl
      _ -> @default_grant_ttl_seconds
    end
  end

  defp create_auth_code(challenge, user_id, grant_id) do
    code = McpOAuthAuthCode.generate_code()

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@auth_code_ttl_seconds, :second)
      |> DateTime.truncate(:second)

    McpOAuthAuthCode.create(%{
      code: code,
      client_id: challenge.client_id,
      user_id: user_id,
      redirect_uri: challenge.redirect_uri,
      code_challenge: challenge.code_challenge,
      grant_id: grant_id,
      expires_at: expires_at
    })
  end

  defp available_grants_for_user(user_id) do
    org_ids =
      try do
        Guard.Api.Rbac.list_accessible_orgs(user_id)
      rescue
        _ -> []
      end

    available_orgs =
      Enum.map(org_ids, fn org_id ->
        permissions = list_org_permissions(user_id, org_id)

        %{
          org_id: org_id,
          org_name: organization_name(org_id),
          can_view: has_permission?(permissions, @org_view_permission),
          can_run_workflows: has_permission?(permissions, @org_run_permission)
        }
      end)

    available_projects =
      org_ids
      |> Enum.flat_map(fn org_id ->
        project_ids =
          try do
            Guard.Api.Rbac.list_accessible_projects(org_id, user_id)
          rescue
            _ -> []
          end

        Enum.map(project_ids, fn project_id ->
          permissions = list_project_permissions(user_id, org_id, project_id)

          %{
            project_id: project_id,
            org_id: org_id,
            org_name: organization_name(org_id),
            project_name: project_name(project_id),
            can_view: has_permission?(permissions, @project_view_permission),
            can_run_workflows: has_permission?(permissions, @project_run_permission),
            can_view_logs: has_any_permission?(permissions, @project_log_permissions)
          }
        end)
      end)

    {available_orgs, available_projects}
  end

  defp list_org_permissions(user_id, org_id) do
    try do
      Guard.Api.Rbac.list_user_permissions(user_id, org_id)
    rescue
      _ -> []
    end
  end

  defp list_project_permissions(user_id, org_id, project_id) do
    try do
      Guard.Api.Rbac.list_user_permissions(user_id, org_id, project_id)
    rescue
      _ -> []
    end
  end

  defp organization_name(org_id) do
    if valid_uuid?(org_id) do
      case Organization.get_by_id(org_id) do
        {:ok, org} -> org.name || ""
        {:error, _} -> ""
      end
    else
      ""
    end
  end

  defp project_name(project_id) do
    if valid_uuid?(project_id) do
      case Repo.get_by(Guard.Repo.Project, project_id: project_id) do
        nil -> ""
        project -> project.repo_name || ""
      end
    else
      ""
    end
  end

  defp enrich_org_grants(org_grants) do
    Enum.map(org_grants, fn org_grant ->
      Map.put(org_grant, :org_name, organization_name(org_grant.org_id))
    end)
  end

  defp enrich_project_grants(project_grants) do
    Enum.map(project_grants, fn project_grant ->
      Map.put(project_grant, :project_name, project_name(project_grant.project_id))
    end)
  end

  defp org_grant_input_to_attrs(%McpGrant.OrgGrantInput{} = org_grant) do
    %{
      org_id: org_grant.org_id,
      can_view: org_grant.can_view,
      can_run_workflows: org_grant.can_run_workflows
    }
  end

  defp project_grant_input_to_attrs(%McpGrant.ProjectGrantInput{} = project_grant) do
    %{
      project_id: project_grant.project_id,
      org_id: project_grant.org_id,
      can_view: project_grant.can_view,
      can_run_workflows: project_grant.can_run_workflows,
      can_view_logs: project_grant.can_view_logs
    }
  end

  defp to_proto_grant(grant) do
    grant = Repo.preload(grant, [:org_grants, :project_grants])

    McpGrant.McpGrant.new(
      id: grant.id,
      user_id: grant.user_id,
      client_id: grant.client_id,
      client_name: grant.client_name || "",
      tool_scopes: grant.tool_scopes || [],
      org_grants: Enum.map(grant.org_grants, &to_proto_org_grant/1),
      project_grants: Enum.map(grant.project_grants, &to_proto_project_grant/1),
      created_at: to_proto_timestamp(grant.created_at),
      expires_at: to_proto_timestamp(grant.expires_at),
      revoked_at: to_proto_timestamp(grant.revoked_at),
      last_used_at: to_proto_timestamp(grant.last_used_at)
    )
  end

  defp to_proto_org_grant(org_grant) do
    McpGrant.OrgGrant.new(
      org_id: org_grant.org_id,
      org_name: org_grant.org_name || "",
      can_view: org_grant.can_view,
      can_run_workflows: org_grant.can_run_workflows
    )
  end

  defp to_proto_project_grant(project_grant) do
    McpGrant.ProjectGrant.new(
      project_id: project_grant.project_id,
      org_id: project_grant.org_id,
      project_name: project_grant.project_name || "",
      can_view: project_grant.can_view,
      can_run_workflows: project_grant.can_run_workflows,
      can_view_logs: project_grant.can_view_logs
    )
  end

  defp to_proto_challenge(challenge) do
    McpGrant.ConsentChallenge.new(
      id: challenge.id,
      user_id: challenge.user_id,
      client_id: challenge.client_id,
      client_name: challenge.client_name || "",
      redirect_uri: challenge.redirect_uri,
      code_challenge: challenge.code_challenge,
      code_challenge_method: challenge.code_challenge_method,
      state: challenge.state || "",
      requested_scope: challenge.requested_scope || "",
      created_at: to_proto_timestamp(challenge.created_at),
      expires_at: to_proto_timestamp(challenge.expires_at),
      consumed_at: to_proto_timestamp(challenge.consumed_at)
    )
  end

  defp to_proto_selection(selection) do
    McpGrant.GrantSelection.new(
      tool_scopes: selection.tool_scopes,
      org_grants:
        Enum.map(selection.org_grants, fn org_grant ->
          McpGrant.OrgGrantInput.new(
            org_id: org_grant.org_id,
            can_view: org_grant.can_view,
            can_run_workflows: org_grant.can_run_workflows
          )
        end),
      project_grants:
        Enum.map(selection.project_grants, fn project_grant ->
          McpGrant.ProjectGrantInput.new(
            project_id: project_grant.project_id,
            org_id: project_grant.org_id,
            can_view: project_grant.can_view,
            can_run_workflows: project_grant.can_run_workflows,
            can_view_logs: project_grant.can_view_logs
          )
        end)
    )
  end

  defp to_proto_grantable_org(org_grant) do
    McpGrant.GrantableOrganization.new(
      org_id: org_grant.org_id,
      org_name: org_grant.org_name,
      can_view: org_grant.can_view,
      can_run_workflows: org_grant.can_run_workflows
    )
  end

  defp to_proto_grantable_project(project_grant) do
    McpGrant.GrantableProject.new(
      project_id: project_grant.project_id,
      org_id: project_grant.org_id,
      org_name: project_grant.org_name,
      project_name: project_grant.project_name,
      can_view: project_grant.can_view,
      can_run_workflows: project_grant.can_run_workflows,
      can_view_logs: project_grant.can_view_logs
    )
  end

  defp to_proto_timestamp(nil), do: nil

  defp to_proto_timestamp(%DateTime{} = dt) do
    Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(dt), nanos: 0)
  end

  defp validate_uuid!(uuid, field_name) do
    if not valid_uuid?(uuid) do
      grpc_error!(:invalid_argument, "#{field_name} must be a valid UUID")
    end
  end

  defp validate_redirect_uri(client, redirect_uri) do
    if McpOAuthClient.valid_redirect_uri?(client, redirect_uri) do
      :ok
    else
      {:error, "redirect_uri does not match registered URIs"}
    end
  end

  defp validate_code_challenge_method("S256"), do: :ok

  defp validate_code_challenge_method(_),
    do: {:error, "code_challenge_method must be S256"}

  defp has_permission?(permissions, permission), do: permission in permissions

  defp has_any_permission?(permissions, candidates),
    do: Enum.any?(candidates, fn permission -> permission in permissions end)

  defp invalid_reason(grant) do
    cond do
      not is_nil(grant.revoked_at) -> "revoked"
      expired?(grant.expires_at) -> "expired"
      true -> "invalid"
    end
  end

  defp expired?(nil), do: false

  defp expired?(expires_at) do
    DateTime.compare(expires_at, DateTime.utc_now() |> DateTime.truncate(:second)) != :gt
  end

  defp handle_changeset_error(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
      |> Enum.map_join(", ", fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)

    grpc_error!(:invalid_argument, errors)
  end

  defp handle_changeset_error(reason), do: grpc_error!(:internal, inspect(reason))
end
