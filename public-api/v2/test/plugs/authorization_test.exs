defmodule PublicAPI.Plugs.AuthorizationTest do
  use ExUnit.Case
  use Plug.Test
  # import Mock
  alias Support.Stubs.PermissionPatrol

  defmodule ViewOrgSettings do
    use Plug.Builder

    plug(Support.Plugs.TestHelper)

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

    plug(PublicAPI.Plugs.RequestAssigns)

    plug(PublicAPI.Plugs.Authorization,
      permissions: ["project.view"]
    )

    plug(:workflow)

    def workflow(conn, _opts) do
      Plug.Conn.send_resp(conn, 200, "response")
    end
  end

  defmodule CreatingWorkflow do
    use Plug.Builder

    plug(Support.Plugs.TestHelper)

    plug(PublicAPI.Plugs.RequestAssigns)

    plug(PublicAPI.Plugs.Authorization,
      permissions: ["project.job.rerun"]
    )

    plug(:workflow)

    def workflow(conn, _opts) do
      Plug.Conn.send_resp(conn, 200, "response")
    end
  end

  defmodule CreatePeriodic do
    use Plug.Builder

    plug(PublicAPI.Plugs.RequestAssigns)
    plug(Support.Plugs.TestHelper)

    plug(PublicAPI.Plugs.Authorization,
      permissions: ["project.scheduler.manage"]
    )
  end

  describe "endpoints using only allow organization settings view and rerun of a workflow" do
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

      {:ok, %{org_id: organization_id, user_id: user_id}}
    end

    test "reads org settings", ctx do
      conn =
        conn(:get, "/")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)

      conn = ViewOrgSettings.call(conn, [])
      assert conn.status == 200
    end

    test "not allowed to create pipeline", ctx do
      conn =
        conn(:post, "/")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)

      conn = CreatingWorkflow.call(conn, [])
      assert conn.status == 404
    end

    test "not allowed to create periodic", ctx do
      conn =
        conn(:post, "/")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)

      conn = CreatePeriodic.call(conn, [])
      assert conn.status == 404
    end

    test "gets workflows with project name", ctx do
      conn =
        conn(:get, "/?project_name=test-einz")
        |> put_req_header("x-semaphore-user-id", ctx.user_id)
        |> put_req_header("x-semaphore-org-id", ctx.org_id)

      conn = GetWorkflow.call(conn, [])
      assert conn.status == 200
    end
  end
end
