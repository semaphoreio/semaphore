defmodule PublicAPI.Plugs.AuditLoggerTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog
  alias Support.Stubs.PermissionPatrol

  defmodule ViewOrgSettings do
    use Plug.Builder

    plug(PublicAPI.Plugs.AuditLogger, operation_id: "Organization.View")

    plug(PublicAPI.Plugs.RequestAssigns)

    plug(PublicAPI.Plugs.Authorization,
      permissions: ["organization.general_settings.view"]
    )

    plug(:settings)

    def settings(conn, _opts) do
      Plug.Conn.send_resp(conn, 200, "response")
    end
  end

  defmodule GetWorkflow do
    use Plug.Builder

    plug(Support.Plugs.TestHelper)
    plug(PublicAPI.Plugs.AuditLogger, operation_id: "Workflow.View")

    plug(PublicAPI.Plugs.RequestAssigns)

    plug(PublicAPI.Plugs.Authorization,
      permissions: ["project.view"]
    )

    plug(:workflow)

    def workflow(conn, _opts) do
      Plug.Conn.send_resp(conn, 200, "response")
    end
  end

  describe "Only allowed to view organization, logs in all cases" do
    setup do
      organization_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.general_settings.view"
      )

      %{api_model: project} =
        Support.Stubs.Project.create(%{id: organization_id}, %{id: user_id}, name: "test-einz")

      PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "project.view",
        project.metadata.id
      )

      {:ok, %{org_id: organization_id, user_id: user_id, project_id: project.metadata.id}}
    end

    test "reads org settings", ctx do
      conn =
        conn(:get, "/")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)

      log =
        capture_log(fn ->
          conn = ViewOrgSettings.call(conn, [])
          assert conn.status == 200
        end)

      assert log =~ "AuditLog"
      assert log =~ ctx.user_id
      assert log =~ ctx.org_id
      assert log =~ "authorized_permissions: true"
    end

    test "allowed to view a project based on pipeline", ctx do
      conn =
        conn(:get, "/?project_id=#{ctx.project_id}")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)
        |> put_req_header("user-agent", "test-agent")

      log =
        capture_log(fn ->
          conn = GetWorkflow.call(conn, [])
          assert conn.status == 200
        end)

      assert log =~ "AuditLog"
      assert log =~ ctx.user_id
      assert log =~ ctx.org_id
      assert log =~ "Workflow.View"
      assert log =~ "authorized_project: true"
      assert log =~ "authorized_permissions: true"
      assert log =~ "permissions: [\"project.view\"]"
    end

    test "not allowed to create pipeline", ctx do
      conn =
        conn(:post, "/")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)
        |> put_req_header("user-agent", "test-agent")

      log =
        capture_log(fn ->
          conn = GetWorkflow.call(conn, [])
          assert conn.status == 404
        end)

      assert log =~ "AuditLog"
      assert log =~ ctx.user_id
      assert log =~ ctx.org_id
      assert log =~ "Workflow.View"
      assert log =~ "test-agent"
      assert log =~ "authorized_project: false"
      assert log =~ "permissions: [\"project.view\"]"
    end
  end
end
