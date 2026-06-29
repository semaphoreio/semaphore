defmodule PipelinesAPI.Roles.Update do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
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

      permissions =
        (params["permissions"] || [])
        |> Enum.map(fn name -> RBAC.Permission.new(name: name) end)

      scope =
        case params["scope"] do
          "project" -> RBAC.Scope.value(:SCOPE_PROJECT)
          "org" -> RBAC.Scope.value(:SCOPE_ORG)
          _ -> RBAC.Scope.value(:SCOPE_UNSPECIFIED)
        end

      role =
        RBAC.Role.new(
          id: params["id"],
          name: params["name"] || "",
          org_id: org_id,
          scope: scope,
          description: params["description"] || "",
          rbac_permissions: permissions
        )

      %{role: role, requester_id: requester_id}
      |> RBACClient.modify_role()
      |> RespCommon.respond(conn)
    end)
  end
end
