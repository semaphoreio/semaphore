defmodule PipelinesAPI.Roles.Create do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias InternalApi.RBAC
  alias Plug.Conn

  import PipelinesAPI.Roles.Authorize, only: [authorize_manage_roles: 2]

  plug(:authorize_manage_roles)
  plug(:create_role)

  def create_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["roles_create"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      params = conn.params

      permissions =
        (params["permissions"] || [])
        |> Enum.map(fn name -> RBAC.Permission.new(name: name) end)

      scope =
        case params["scope"] do
          "project" -> RBAC.Scope.value(:SCOPE_PROJECT)
          _ -> RBAC.Scope.value(:SCOPE_ORG)
        end

      role =
        RBAC.Role.new(
          name: params["name"] || "",
          org_id: org_id,
          scope: scope,
          description: params["description"] || "",
          rbac_permissions: permissions
        )

      %{role: role}
      |> RBACClient.modify_role()
      |> RespCommon.respond(conn)
    end)
  end
end
