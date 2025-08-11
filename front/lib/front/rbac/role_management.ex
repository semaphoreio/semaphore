defmodule Front.RBAC.RoleManagement do
  @moduledoc """
  Managing roles and assiging them to users
  """

  require Logger

  alias InternalApi.RBAC

  @type id :: Ecto.UUID.t()
  @type role :: RBAC.Role.t()

  @extended_grpc_timeout 30_000

  @doc """
  Lists all permissions avaiable within given scope

  Accepts scope in the following formats:
  - "organization" or "project" (as strings)
  - :organization or :project (as atoms)
  - :SCOPE_ORG, :SCOPE_PROJECT or :SCOPE_UNSPECIFIED (as Protobuf enum values)
  - 0, 1 or 2 (as integers mapped to Protobuf enum values)
  """
  @spec list_existing_permissions(String.t() | atom() | integer()) ::
          {:ok, [RBAC.Permission.t()]} | {:error, any()}

  def list_existing_permissions("organization"),
    do: list_existing_permissions(:SCOPE_ORG)

  def list_existing_permissions("project"),
    do: list_existing_permissions(:SCOPE_PROJECT)

  def list_existing_permissions(""),
    do: list_existing_permissions(:SCOPE_UNSPECIFIED)

  def list_existing_permissions(scope) when is_binary(scope),
    do: {:error, :invalid_scope}

  def list_existing_permissions(:organization),
    do: list_existing_permissions(:SCOPE_ORG)

  def list_existing_permissions(:project),
    do: list_existing_permissions(:SCOPE_PROJECT)

  def list_existing_permissions(:unspecified),
    do: list_existing_permissions(:SCOPE_UNSPECIFIED)

  def list_existing_permissions(nil),
    do: list_existing_permissions(:SCOPE_UNSPECIFIED)

  def list_existing_permissions(scope_value) when is_integer(scope_value),
    do: list_existing_permissions(InternalApi.RBAC.Scope.key(scope_value))

  def list_existing_permissions(scope) when is_atom(scope) do
    Watchman.benchmark("fetch_rbac_permissions.duration", fn ->
      req = RBAC.ListExistingPermissionsRequest.new(scope: RBAC.Scope.value(scope))

      case channel() |> RBAC.RBAC.Stub.list_existing_permissions(req) do
        {:ok, resp} ->
          {:ok, resp.permissions}

        e ->
          Watchman.increment("fetch_rbac_permissions.failure")

          Logger.error(
            "Error while fetching existing permissions. " <>
              "scope: #{inspect(scope)}. Error: #{inspect(e)}"
          )

          e
      end
    end)
  end

  @doc """
    List all roles available to a given organization.

    - scope: this paramether can be "project_scope" or "org_scope". Based on this
             only project level or organization level roles will be listed. If this
             parameter is missing, all organization roles will be returned,
             regardless of the scope
  """
  @spec list_possible_roles(id()) :: {:ok, [role()]} | {:error, GRPC.RPCError}
  def list_possible_roles(org_id, scope \\ "") do
    Watchman.benchmark("fetch_rbac_roles.duration", fn ->
      scope_enum =
        case scope do
          "org_scope" -> RBAC.Scope.value(:SCOPE_ORG)
          "project_scope" -> RBAC.Scope.value(:SCOPE_PROJECT)
          _ -> RBAC.Scope.value(:SCOPE_UNSPECIFIED)
        end

      req = RBAC.ListRolesRequest.new(org_id: org_id, scope: scope_enum)

      case channel() |> RBAC.RBAC.Stub.list_roles(req) do
        {:ok, resp} ->
          {:ok, sort_roles(resp.roles, scope)}

        e ->
          Watchman.increment("fetch_rbac_roles.failure")

          Logger.error(
            "Error while fetching possible roles. Org_id: #{inspect(org_id)}, " <>
              "scope: #{inspect(scope)}. Error: #{inspect(e)}"
          )

          e
      end
    end)
  end

  @doc """
    Fetches a role by its ID
  """
  @spec describe_role(id(), id()) :: {:ok, RBAC.Role.t()} | {:error, any()}
  def describe_role(org_id, role_id) do
    Watchman.benchmark("fetch_rbac_role.duration", fn ->
      req = RBAC.DescribeRoleRequest.new(org_id: org_id, role_id: role_id)

      case channel() |> RBAC.RBAC.Stub.describe_role(req) do
        {:ok, resp} -> {:ok, resp.role}
        e -> e
      end
    end)
  end

  @doc """
  Modifies an existing role.

  - role: the role to be modified (in the protobuf structure format)
  - requester_id: the ID of the user who is modifying the role
  """
  @spec modify_role(RBAC.Role.t(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def modify_role(role = %RBAC.Role{}, requester_id) when is_binary(requester_id) do
    Watchman.benchmark("modify_role.duration", fn ->
      Logger.info(
        "Modifying role: org_id: #{role.org_id}, scope: #{role.scope}, role_id: #{role.id}, role_name: #{role.name}"
      )

      request = RBAC.ModifyRoleRequest.new(role: role, requester_id: requester_id)

      case channel() |> RBAC.RBAC.Stub.modify_role(request, timeout: @extended_grpc_timeout) do
        {:ok, resp} -> {:ok, %{role_id: resp.role.id}}
        e -> e
      end
    end)
  end

  def modify_role(_role = %RBAC.Role{}, _requester_id),
    do: {:error, :invalid_requester_id}

  def modify_role(_role, _requester_id),
    do: {:error, :invalid_role}

  @doc """
  Removes an existing role

  - org_id: the ID of the organization to which the role belongs
  - requester_id: the ID of the user who is removing the role
  - role_id: the ID of the role to be removed
  """
  @spec destroy_role(id(), id(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def destroy_role(org_id, requester_id, role_id)
      when is_binary(org_id) and is_binary(role_id) and is_binary(requester_id) do
    Watchman.benchmark("destroy_role.duration", fn ->
      Logger.info("Removing role: org_id: #{org_id}, role_id: #{role_id}")

      req =
        RBAC.DestroyRoleRequest.new(org_id: org_id, role_id: role_id, requester_id: requester_id)

      case channel() |> RBAC.RBAC.Stub.destroy_role(req, timeout: @extended_grpc_timeout) do
        {:ok, resp} -> {:ok, %{role_id: resp.role_id}}
        e -> e
      end
    end)
  end

  @doc """
    Assigning a role to a subject (user/group) within the organization or project.
    If the 'project_id' parameter is not passed, it is interpreted as the role being assigned
    within the organization scope.
  """
  @spec assign_role(id(), id(), id(), id(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, any}
  def assign_role(
        requester_id,
        org_id,
        subject_id,
        role_id,
        project_id \\ "",
        subject_type \\ "user"
      ) do
    Watchman.benchmark("assign_role.duration", fn ->
      Logger.info(
        "Assigning role: subject_id: #{subject_id}, org_id: #{org_id}, role_id: #{role_id}, project_id: #{project_id}, subject_type: #{subject_type}"
      )

      subject_type =
        case subject_type do
          "service_account" ->
            InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT)

          "group" ->
            InternalApi.RBAC.SubjectType.value(:GROUP)

          # Defaults to user
          "user" ->
            InternalApi.RBAC.SubjectType.value(:USER)

          _ ->
            Logger.warn("Unrecognized subject type: #{subject_type}, defaulting to user")
            InternalApi.RBAC.SubjectType.value(:USER)
        end

      subject = RBAC.Subject.new(subject_id: subject_id, type: subject_type)

      req =
        RBAC.AssignRoleRequest.new(
          role_assignment:
            RBAC.RoleAssignment.new(
              role_id: role_id,
              org_id: org_id,
              project_id: project_id,
              subject: subject
            ),
          requester_id: requester_id
        )

      case channel() |> RBAC.RBAC.Stub.assign_role(req, timeout: @extended_grpc_timeout) do
        {:ok, _resp} -> {:ok, "Role successfully assigned."}
        e -> e
      end
    end)
  end

  @doc """
    Retracting/revoking the role that a subject (user/group) has within the organization or project.
    Since only one role can be manually assigned, there is no need to specify which role is being
    retracted
  """
  @spec retract_role(id(), id(), id(), String.t()) :: {:ok, String.t()} | {:error, any}
  def retract_role(requester_id, org_id, subject_id, project_id \\ "") do
    Watchman.benchmark("remove_member.duration", fn ->
      Logger.info(
        "Retracting role: subject_id: #{subject_id}, org_id: #{org_id}, project_id: #{project_id}"
      )

      req =
        RBAC.RetractRoleRequest.new(
          role_assignment:
            RBAC.RoleAssignment.new(
              org_id: org_id,
              project_id: project_id,
              subject: RBAC.Subject.new(subject_id: subject_id)
            ),
          requester_id: requester_id
        )

      case channel() |> RBAC.RBAC.Stub.retract_role(req, timeout: @extended_grpc_timeout) do
        {:ok, _resp} -> {:ok, "Role successfully retracted"}
        e -> e
      end
    end)
  end

  defp sort_roles(roles, "project_scope") do
    Enum.sort_by(roles, fn role ->
      case role do
        %{name: "Admin"} -> 0
        %{name: "Contributor"} -> 1
        %{name: "Reader"} -> 2
        _ -> 3
      end
    end)
  end

  defp sort_roles(roles, "org_scope") do
    Enum.sort_by(roles, fn role ->
      case role do
        %{name: "Owner"} -> 0
        %{name: "Admin"} -> 1
        %{name: "Member"} -> 2
        _ -> 3
      end
    end)
  end

  defp sort_roles(roles, _), do: roles

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(api_endpoint())
    ch
  end

  defp api_endpoint do
    Application.fetch_env!(:front, :rbac_grpc_endpoint)
  end
end
