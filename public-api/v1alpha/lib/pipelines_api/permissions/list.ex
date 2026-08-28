defmodule PipelinesAPI.Permissions.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias InternalApi.RBAC

  import PipelinesAPI.Roles.Authorize, only: [authorize_view_roles: 2]

  plug(:authorize_view_roles)
  plug(:list_permissions)

  def list_permissions(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["permissions_list"], fn ->
      scope =
        case conn.params["scope"] do
          "project" -> RBAC.Scope.value(:SCOPE_PROJECT)
          "org" -> RBAC.Scope.value(:SCOPE_ORG)
          _ -> RBAC.Scope.value(:SCOPE_ORG)
        end

      %{scope: scope}
      |> RBACClient.list_existing_permissions()
      |> RespCommon.respond(conn)
    end)
  end
end
