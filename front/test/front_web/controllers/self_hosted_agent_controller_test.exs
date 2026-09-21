defmodule FrontWeb.SelfHostedAgentControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user_id = DB.first(:users) |> Map.get(:id)
    org_id = DB.first(:organizations) |> Map.get(:id)

    Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [conn: conn, org_id: org_id, user_id: user_id]
  end

  describe "GET agents" do
    test "returns agents for an existing agent type", %{conn: conn, org_id: org_id} do
      Support.Stubs.SelfHostedAgent.create(org_id, "s1-test")
      Support.Stubs.SelfHostedAgent.add_agent(org_id, "s1-test", "agent-001")

      conn = get(conn, "/self_hosted_agents/s1-test/agents")

      assert %{"agents" => agents, "total_agents" => 1} = json_response(conn, 200)
      assert length(agents) == 1
    end

    test "returns 404 when agent type does not exist", %{conn: conn} do
      GrpcMock.expect(SelfHostedAgentsMock, :describe, fn _req, _ ->
        raise GRPC.RPCError, status: 5, message: "agent type not found"
      end)

      conn = get(conn, "/self_hosted_agents/nonexistent/agents")

      assert json_response(conn, 404) == %{"error" => "agent type not found"}
    end
  end
end
