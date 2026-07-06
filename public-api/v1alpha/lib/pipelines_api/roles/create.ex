defmodule PipelinesAPI.Roles.Create do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Roles.PermissionResolver
  alias PipelinesAPI.Audit
  alias InternalApi.RBAC
  alias Plug.Conn

  import PipelinesAPI.Roles.Authorize, only: [authorize_manage_roles: 2]

  plug(:authorize_manage_roles)
  plug(:create_role)

  def create_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["roles_create"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
      params = conn.params

      scope =
        case params["scope"] do
          "project" -> RBAC.Scope.value(:SCOPE_PROJECT)
          _ -> RBAC.Scope.value(:SCOPE_ORG)
        end

      requested = params["permissions"] || []

      with :ok <-
             PermissionResolver.ensure_requester_holds(scope, requested, requester_id, org_id),
           {:ok, permissions} <- PermissionResolver.resolve(scope, requested) do
        role =
          RBAC.Role.new(
            name: params["name"] || "",
            org_id: org_id,
            scope: scope,
            description: params["description"] || "",
            rbac_permissions: permissions
          )

        %{role: role, requester_id: requester_id}
        |> RBACClient.modify_role()
        |> tap(fn result -> audit_event(result, conn) end)
        |> RespCommon.respond(conn)
      else
        error -> RespCommon.respond(error, conn)
      end
    end)
  end

  defp audit_event({:ok, role}, conn) do
    conn
    |> Audit.new(:RBACRole, :Added)
    |> Audit.add(resource_id: role.id, resource_name: role.name)
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
