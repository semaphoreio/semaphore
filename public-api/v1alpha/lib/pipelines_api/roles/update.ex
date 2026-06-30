defmodule PipelinesAPI.Roles.Update do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Roles.PermissionResolver
  alias InternalApi.RBAC
  alias Plug.Conn

  import PipelinesAPI.Roles.Authorize, only: [authorize_manage_roles: 2]

  plug(:authorize_manage_roles)
  plug(:update_role)

  def update_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["roles_update"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
      params = conn.params
      role_id = params["id"]

      # ModifyRole is a full replace, so fetch the current role and keep every
      # field the caller did not supply. Otherwise a partial update — e.g. only
      # --description — would blank the role's permissions, name, etc.
      with {:ok, current} <- RBACClient.describe_role(%{role_id: role_id, org_id: org_id}),
           scope <- scope_value(params["scope"] || current.scope),
           :ok <-
             PermissionResolver.ensure_requester_holds(
               scope,
               params["permissions"] || [],
               requester_id,
               org_id
             ),
           {:ok, permissions} <-
             PermissionResolver.resolve(scope, params["permissions"] || current.permissions) do
        role =
          RBAC.Role.new(
            id: role_id,
            name: params["name"] || current.name,
            org_id: org_id,
            scope: scope,
            description: params["description"] || current.description,
            rbac_permissions: permissions
          )

        %{role: role, requester_id: requester_id}
        |> RBACClient.modify_role()
        |> RespCommon.respond(conn)
      else
        error -> RespCommon.respond(error, conn)
      end
    end)
  end

  defp scope_value("project"), do: RBAC.Scope.value(:SCOPE_PROJECT)
  defp scope_value("org"), do: RBAC.Scope.value(:SCOPE_ORG)
  defp scope_value(_), do: RBAC.Scope.value(:SCOPE_ORG)
end
