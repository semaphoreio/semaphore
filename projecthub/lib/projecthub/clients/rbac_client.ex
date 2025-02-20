defmodule Projecthub.RbacClient do
  require Logger

  alias InternalApi.RBAC.{
    AssignRoleRequest,
    RoleAssignment,
    Subject,
    ListRolesRequest,
    Scope
  }

  def assign_role(user_id, org_id, project_id, role_name) do
    case get_project_role(org_id, role_name) do
      nil ->
        Logger.error("[Rbac Client] Cant fetch role. Org_id #{inspect(org_id)} role_name #{inspect(role_name)}")

      role ->
        req =
          AssignRoleRequest.new(
            role_assignment:
              RoleAssignment.new(
                role_id: role.id,
                subject: Subject.new(subject_id: user_id),
                org_id: org_id,
                project_id: project_id
              )
          )

        case channel() |> InternalApi.RBAC.RBAC.Stub.assign_role(req, timeout: :timer.seconds(60)) do
          {:ok, _response} ->
            :ok

          e ->
            Logger.error("Error while assigning a role. Req: #{inspect(req)}. Error: #{inspect(e)}")
            e
        end
    end
  end

  defp get_project_role(org_id, role_name) do
    req =
      ListRolesRequest.new(
        org_id: org_id,
        scope: Scope.value(:SCOPE_PROJECT)
      )

    case channel() |> InternalApi.RBAC.RBAC.Stub.list_roles(req) do
      {:ok, resp} ->
        resp.roles |> Enum.find(&(&1.name == role_name))

      e ->
        Logger.error("Error while fetching possible roles. Org_id: #{inspect(org_id)}. Error: #{inspect(e)}")

        e
    end
  end

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(api_endpoint())
    ch
  end

  defp api_endpoint do
    Application.fetch_env!(:projecthub, :rbac_grpc_endpoint)
  end
end
