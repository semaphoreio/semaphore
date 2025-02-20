defmodule Router.SelfHostedAgentsTest do
  use ExUnit.Case

  alias Support.Stubs.SelfHostedAgent
  alias Support.Stubs.PermissionPatrol
  import OpenApiSpex.TestAssertions

  @org_id UUID.uuid4()
  @authorized_user_id UUID.uuid4()
  @unauthorized_user_id UUID.uuid4()

  setup do
    Support.Stubs.reset()

    PermissionPatrol.add_permissions(
      @org_id,
      @authorized_user_id,
      "organization.self_hosted_agents.view"
    )
  end

  describe "GET /agents" do
    test "unauthorized user" do
      assert {404, _} = list_agents(@unauthorized_user_id)
    end

    test "returns 200 with list of agents" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @authorized_user_id)

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-2", @authorized_user_id)

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-3", @authorized_user_id)

      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-1", UUID.uuid4())
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-1", UUID.uuid4())
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-1", UUID.uuid4())

      assert {200, agents} = list_agents(@authorized_user_id)
      assert length(agents) == 3
      check_list(agents)

      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-3", UUID.uuid4())
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-3", UUID.uuid4())
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-2", UUID.uuid4())
      assert {200, agents} = list_agents(@authorized_user_id)
      assert length(agents) == 6
      check_list(agents)

      assert {200, agents} =
               list_agents(@authorized_user_id, %{agent_type: "s1-sh-router-test-list-3"})

      assert length(agents) == 2
      check_list(agents)
    end

    test "list contains agent not owned by requester org" do
      wrong_org = UUID.uuid4()

      SelfHostedAgent.add_agent(wrong_org, "s1-sh-router-test-list-1", UUID.uuid4())
      SelfHostedAgent.add_agent(wrong_org, "s1-sh-router-test-list-1", UUID.uuid4())
      SelfHostedAgent.add_agent(wrong_org, "s1-sh-router-test-list-1", UUID.uuid4())

      GrpcMock.stub(SelfHostedMock, :list_agents, fn req, _opts ->
        alias Support.Stubs.SelfHostedAgent, as: SH
        agents = SH.list_agents(wrong_org, req.agent_type_name)

        %InternalApi.SelfHosted.ListAgentsResponse{
          agents: agents,
          total_pages: 1,
          page: 1
        }
      end)

      assert {404, resp} =
               list_agents(@authorized_user_id, %{agent_type: "s1-sh-router-test-list-1"})

      assert %{"message" => "Not found"} = resp
    end
  end

  describe "GET /agents/{agent_name}" do
    test "unauthorized user" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @authorized_user_id)

      name = UUID.uuid4()
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-1", name)

      assert {404, _} = describe_agent(@unauthorized_user_id, name)
    end

    test "returns 200 with agent" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @authorized_user_id)

      name1 = UUID.uuid4()
      SelfHostedAgent.add_agent(@org_id, "s1-sh-router-test-list-1", name1)

      assert {200, agent} = describe_agent(@authorized_user_id, name1)
      check_describe(agent)
    end

    test "when agent not owned by requester org returns 404" do
      wrong_org = UUID.uuid4()

      SelfHostedAgent.add_agent(wrong_org, "s1-sh-router-test-list-1", UUID.uuid4())

      GrpcMock.stub(SelfHostedMock, :describe_agent, fn req, _opts ->
        alias Support.Stubs.SelfHostedAgent, as: SH
        agent = SH.find_agent(wrong_org, req.agent_name)

        %InternalApi.SelfHosted.DescribeAgentResponse{
          agent: agent
        }
      end)

      assert {404, resp} = describe_agent(@authorized_user_id, "s1-sh-router-test-list-1")
      assert %{"message" => "Not found"} = resp
    end
  end

  defp check_list(response) do
    api_spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "SelfHostedAgents.ListAgentsResponse", api_spec)
  end

  defp check_describe(response) do
    api_spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "SelfHostedAgents.Agent", api_spec)
  end

  defp list_agents(user_id, params \\ %{}) do
    url = "localhost:4004/agents?" <> Plug.Conn.Query.encode(params)
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body = Jason.decode!(body)

    {status_code, body}
  end

  defp describe_agent(user_id, agent_name) do
    url = "localhost:4004/agents/#{agent_name}"
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body = Jason.decode!(body)

    {status_code, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", @org_id}
    ]
end
