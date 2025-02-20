defmodule Router.SelfHostedAgentTypesTest do
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
      "organization.self_hosted_agents.manage"
    )

    PermissionPatrol.add_permissions(
      @org_id,
      @authorized_user_id,
      "organization.self_hosted_agents.view"
    )
  end

  describe "POST /self_hosted_agent_types" do
    test "unauthorized user" do
      params = %{
        "apiVersion" => "v2",
        "kind" => "SelfHostedAgentType",
        "spec" => %{
          "name" => "s1-sh-router-test-create-1",
          "agent_name_settings" => %{"assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT"}
        }
      }

      create_agent_type(params, @unauthorized_user_id, 404, false)
    end

    test "returns 200 with token" do
      params = %{
        "apiVersion" => "v2",
        "kind" => "SelfHostedAgentType",
        "spec" => %{
          "name" => "s1-sh-router-test-create-1",
          "agent_name_settings" => %{
            "assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT",
            "release_after" => 4
          }
        }
      }

      assert response =
               %{"metadata" => metadata, "spec" => spec} =
               create_agent_type(params, @authorized_user_id, 200)

      assert Map.get(metadata, "name") == "s1-sh-router-test-create-1"
      assert Map.get(metadata["status"], "total_agent_count") == 0
      assert Map.get(metadata["status"], "registration_token") != ""

      assert Map.get(spec, "agent_name_settings") == %{
               "assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT",
               "release_after" => 4,
               "aws" => nil
             }

      api_spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "SelfHostedAgents.AgentType", api_spec)
    end
  end

  describe "PUT /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      params = %{
        "apiVersion" => "v2",
        "kind" => "SelfHostedAgentType",
        "spec" => %{
          "name" => "s1-sh-router-test-update-1",
          "agent_name_settings" => %{"assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT"}
        }
      }

      update_agent_type("s1-sh-router-test-update-1", params, @unauthorized_user_id, 404, false)
    end

    test "returns 200" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-update-1", @authorized_user_id)

      params = %{
        "apiVersion" => "v2",
        "kind" => "SelfHostedAgentType",
        "metadata" => %{
          "name" => "s1-sh-router-test-update-1"
        },
        "spec" => %{
          "name" => "s1-sh-router-test-update-1",
          "agent_name_settings" => %{
            "assignment_origin" => "ASSIGNMENT_ORIGIN_AWS_STS",
            "release_after" => 120,
            "aws" => %{
              "account_id" => "1234567890",
              "role_name_patterns" => "role1,role2"
            }
          }
        }
      }

      assert %{"metadata" => metadata, "spec" => spec} =
               update_agent_type("s1-sh-router-test-update-1", params, @authorized_user_id, 200)

      assert Map.get(metadata, "name") == "s1-sh-router-test-update-1"
      assert Map.get(metadata["status"], "total_agent_count") == 0
      assert is_nil(Map.get(metadata["status"], "registration_token"))

      assert Map.get(spec, "agent_name_settings") == %{
               "assignment_origin" => "ASSIGNMENT_ORIGIN_AWS_STS",
               "release_after" => 120,
               "aws" => %{
                 "account_id" => "1234567890",
                 "role_name_patterns" => "role1,role2"
               }
             }
    end

    test "fail to update agent type that is not owned by requester" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-update-1", @authorized_user_id)

      setup_wrong_owner(UUID.uuid4())

      params = %{
        "apiVersion" => "v2",
        "kind" => "SelfHostedAgentType",
        "metadata" => %{
          "name" => "s1-sh-router-test-update-1"
        },
        "spec" => %{
          "name" => "s1-sh-router-test-update-1",
          "agent_name_settings" => %{
            "assignment_origin" => "ASSIGNMENT_ORIGIN_AWS_STS",
            "release_after" => 120,
            "aws" => %{
              "account_id" => "1234567890",
              "role_name_patterns" => "role1,role2"
            }
          }
        }
      }

      assert %{"message" => "Not found"} =
               update_agent_type("s1-sh-router-test-update-1", params, @authorized_user_id, 404)
    end
  end

  describe "GET /self_hosted_agent_types" do
    test "unauthorized user" do
      assert {404, _} = list_agent_types(@unauthorized_user_id, false)
    end

    test "returns 200 with list of types" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @authorized_user_id)

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-2", @authorized_user_id)

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-3", @authorized_user_id)

      assert {200, agent_types} = list_agent_types(@authorized_user_id)

      api_spec = PublicAPI.ApiSpec.spec()
      assert_schema(agent_types, "SelfHostedAgents.AgentTypeListResponse", api_spec)
    end

    test "returns 404 for agent type that is not owned by requester" do
      wrong_org = UUID.uuid4()

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @authorized_user_id)

      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-2", @authorized_user_id)

      GrpcMock.stub(SelfHostedMock, :list_keyset, fn req, _opts ->
        alias Support.Stubs.SelfHostedAgent, as: SH

        agent_types =
          SH.list(req.organization_id)
          |> Enum.map(fn agent -> %{agent | org_id: wrong_org} end)
          |> Enum.map(&SH.Grpc.serialize/1)

        %InternalApi.SelfHosted.ListKeysetResponse{
          agent_types: agent_types,
          next_page_cursor: "asd"
        }
      end)

      assert {404, _} = list_agent_types(@authorized_user_id)
    end
  end

  describe "GET /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      assert {404, _} =
               describe_agent_type("s1-sh-router-test-describe-1", @unauthorized_user_id, false)
    end

    test "returns 200 for existing agent type" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-describe-1", @authorized_user_id)

      assert {200, response} =
               describe_agent_type("s1-sh-router-test-describe-1", @authorized_user_id)

      assert response == %{
               "apiVersion" => "v2",
               "kind" => "SelfHostedAgentType",
               "metadata" => %{
                 "name" => "s1-sh-router-test-describe-1",
                 "created_at" =>
                   DateTime.from_unix!(1_668_202_871_000, :millisecond) |> DateTime.to_iso8601(),
                 "updated_at" =>
                   DateTime.from_unix!(1_668_202_871_000, :millisecond) |> DateTime.to_iso8601(),
                 "org_id" => @org_id,
                 "status" => %{
                   "total_agent_count" => 0
                 }
               },
               "spec" => %{
                 "name" => "s1-sh-router-test-describe-1",
                 "agent_name_settings" => %{
                   "assignment_origin" => "ASSIGNMENT_ORIGIN_AGENT",
                   "release_after" => 0,
                   "aws" => nil
                 }
               }
             }
    end

    test "returns 404 for agent type that does not exist" do
      assert {404, _} = describe_agent_type("s1-sh-router-test-describe-2", @authorized_user_id)
    end

    test "returns 404 for agent type that is not owned by the org" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-describe-1", @authorized_user_id)

      setup_wrong_owner(UUID.uuid4())

      assert {404, _} = describe_agent_type("s1-sh-router-test-describe-2", @authorized_user_id)
    end
  end

  describe "DELETE /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      delete_agent_type("s1-sh-router-test-delete-1", @unauthorized_user_id, 404, false)
    end

    test "returns 200 and deletes existing agent type" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-delete-1", @authorized_user_id)

      assert {200, _} = describe_agent_type("s1-sh-router-test-delete-1", @authorized_user_id)

      # agent type is deleted and no longer exists
      delete_agent_type("s1-sh-router-test-delete-1", @authorized_user_id, 200)
      assert {404, _} = describe_agent_type("s1-sh-router-test-delete-1", @authorized_user_id)
    end

    test "returns 404 for agent type that does not exist" do
      delete_agent_type("s1-sh-router-test-delete-does-not-exist", @authorized_user_id, 404)
    end

    test "returns 404 for agent type that is not owned by the org" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-describe-1", @authorized_user_id)

      setup_wrong_owner(UUID.uuid4())

      delete_agent_type("s1-sh-router-test-delete-1", @authorized_user_id, 404)
    end
  end

  describe "POST /self_hosted_agent_types/:name/disable_all" do
    test "unauthorized user" do
      delete_agent_type("s1-sh-router-test-disable-all-1", @unauthorized_user_id, 404, false)
    end

    test "returns 200 and disables idle agents" do
      agent_type = "s1-sh-router-test-disable-all-2"
      SelfHostedAgent.create(@org_id, agent_type, @authorized_user_id)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-001", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-002", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-003", :RUNNING_JOB)

      # no agents are disabled
      assert 0 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )

      params = %{"only_idle" => "true"}
      disable_all_agents(agent_type, params, @authorized_user_id, 200)

      # only the 2 idle agents are disabled
      assert 2 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end

    test "returns 200 and disables all agents" do
      agent_type = "s1-sh-router-test-disable-all-3"
      SelfHostedAgent.create(@org_id, agent_type, @authorized_user_id)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-001", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-002", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-003", :RUNNING_JOB)

      # no agents are disabled
      assert 0 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )

      params = %{"only_idle" => "false"}
      disable_all_agents(agent_type, params, @authorized_user_id, 200)

      # only the 2 idle agents are disabled
      assert 3 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end

    test "returns 422 on bad argument" do
      agent_type = "s1-sh-router-test-disable-all-4"
      SelfHostedAgent.create(@org_id, agent_type, @authorized_user_id)

      params = %{"only_idle" => "this-is-not-valid"}

      response = disable_all_agents(agent_type, params, @authorized_user_id, 422)

      api_spec = PublicAPI.ApiSpec.spec()
      assert_schema(response, "Error", api_spec)
    end

    test "returns 404 when disabling agents that are not owned by requester org" do
      agent_type = "s1-sh-router-test-disable-all-3"
      SelfHostedAgent.create(@org_id, agent_type, @authorized_user_id)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-001", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-002", :WAITING_FOR_JOB)
      SelfHostedAgent.add_agent(@org_id, agent_type, "agent-003", :RUNNING_JOB)

      # no agents are disabled
      assert 0 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )

      setup_wrong_owner(UUID.uuid4())

      params = %{"only_idle" => "false"}
      disable_all_agents(agent_type, params, @authorized_user_id, 404)

      # no agents are disabled
      assert 0 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end
  end

  defp create_agent_type(args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types"

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.post(url, Jason.encode!(args), headers(user_id))

    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp update_agent_type(name, args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.put(url, Jason.encode!(args), headers(user_id))

    IO.inspect(body)
    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp disable_all_agents(name, args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name <> "/disable_all"

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.post(url, Jason.encode!(args), headers(user_id))

    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp delete_agent_type(name, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.delete(url, headers(user_id))
    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp list_agent_types(user_id, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types"
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp describe_agent_type(agent_type_name, user_id, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> agent_type_name
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Jason.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp setup_wrong_owner(wrong_org) do
    GrpcMock.stub(SelfHostedMock, :describe, fn req, _opts ->
      alias Support.Stubs.SelfHostedAgent, as: SH
      agent_type = SH.find(req.organization_id, req.name)
      agent_type = %{agent_type | org_id: wrong_org}

      %InternalApi.SelfHosted.DescribeResponse{
        agent_type: SH.Grpc.serialize(agent_type)
      }
    end)
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", @org_id}
    ]
end
