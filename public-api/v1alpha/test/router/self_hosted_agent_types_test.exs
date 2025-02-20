defmodule Router.SelfHostedAgentTypesTest do
  use ExUnit.Case

  alias Support.Stubs.SelfHostedAgent

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()
    :ok
  end

  describe "POST /self_hosted_agent_types" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.manage")
        )
      end)

      params = %{"metadata" => %{"name" => "s1-sh-router-test-create-1"}}
      create_agent_type(params, @user_id, 401, false)
    end

    test "returns 200 with token" do
      params = %{"metadata" => %{"name" => "s1-sh-router-test-create-1"}}

      assert %{"metadata" => metadata, "spec" => spec, "status" => status} =
               create_agent_type(params, @user_id, 200)

      assert Map.get(metadata, "name") == "s1-sh-router-test-create-1"
      assert Map.get(metadata, "create_time") == 1_668_202_871
      assert Map.get(metadata, "update_time") == 1_668_202_871
      assert Map.get(status, "total_agent_count") == 0
      assert Map.get(status, "registration_token") != ""

      assert Map.get(spec, "agent_name_settings") == %{
               "assignment_origin" => "assignment_origin_agent",
               "release_after" => 0,
               "aws" => nil
             }
    end
  end

  describe "PATCH /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.manage")
        )
      end)

      params = %{"metadata" => %{"name" => "s1-sh-router-test-update-1"}}
      update_agent_type("s1-sh-router-test-update-1", params, @user_id, 401, false)
    end

    test "returns 200" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-update-1", @user_id)

      params = %{
        "metadata" => %{
          "name" => "s1-sh-router-test-update-1"
        },
        "spec" => %{
          "agent_name_settings" => %{
            "assignment_origin" => "assignment_origin_aws_sts",
            "release_after" => 120,
            "aws" => %{
              "account_id" => "1234567890",
              "role_name_patterns" => "role1,role2"
            }
          }
        }
      }

      assert %{"metadata" => metadata, "spec" => spec, "status" => status} =
               update_agent_type("s1-sh-router-test-update-1", params, @user_id, 200)

      assert Map.get(metadata, "name") == "s1-sh-router-test-update-1"
      assert Map.get(metadata, "create_time") == 1_668_202_871
      assert Map.get(metadata, "update_time") == 1_668_202_871
      assert Map.get(status, "total_agent_count") == 0
      assert is_nil(Map.get(status, "registration_token"))

      assert Map.get(spec, "agent_name_settings") == %{
               "assignment_origin" => "assignment_origin_aws_sts",
               "release_after" => 120,
               "aws" => %{
                 "account_id" => "1234567890",
                 "role_name_patterns" => "role1,role2"
               }
             }
    end
  end

  describe "GET /self_hosted_agent_types" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.view")
        )
      end)

      assert {401, _} = list_agent_types(@user_id, false)
    end

    test "returns 200 with list of types" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-1", @user_id)
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-2", @user_id)
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-list-3", @user_id)

      assert {200, %{"agent_types" => agent_types}} = list_agent_types(@user_id)

      assert agent_types == [
               %{
                 "metadata" => %{
                   "name" => "s1-sh-router-test-list-1",
                   "create_time" => 1_668_202_871,
                   "update_time" => 1_668_202_871
                 },
                 "spec" => %{
                   "agent_name_settings" => %{
                     "assignment_origin" => "assignment_origin_agent",
                     "aws" => nil,
                     "release_after" => 0
                   }
                 },
                 "status" => %{
                   "total_agent_count" => 0
                 }
               },
               %{
                 "metadata" => %{
                   "name" => "s1-sh-router-test-list-2",
                   "create_time" => 1_668_202_871,
                   "update_time" => 1_668_202_871
                 },
                 "spec" => %{
                   "agent_name_settings" => %{
                     "assignment_origin" => "assignment_origin_agent",
                     "aws" => nil,
                     "release_after" => 0
                   }
                 },
                 "status" => %{
                   "total_agent_count" => 0
                 }
               },
               %{
                 "metadata" => %{
                   "name" => "s1-sh-router-test-list-3",
                   "create_time" => 1_668_202_871,
                   "update_time" => 1_668_202_871
                 },
                 "spec" => %{
                   "agent_name_settings" => %{
                     "assignment_origin" => "assignment_origin_agent",
                     "aws" => nil,
                     "release_after" => 0
                   }
                 },
                 "status" => %{
                   "total_agent_count" => 0
                 }
               }
             ]
    end
  end

  describe "GET /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.view")
        )
      end)

      assert {401, _} = describe_agent_type("s1-sh-router-test-describe-1", @user_id, false)
    end

    test "returns 200 for existing agent type" do
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-describe-1", @user_id)
      assert {200, response} = describe_agent_type("s1-sh-router-test-describe-1", @user_id)

      assert response == %{
               "metadata" => %{
                 "name" => "s1-sh-router-test-describe-1",
                 "create_time" => 1_668_202_871,
                 "update_time" => 1_668_202_871
               },
               "spec" => %{
                 "agent_name_settings" => %{
                   "assignment_origin" => "assignment_origin_agent",
                   "aws" => nil,
                   "release_after" => 0
                 }
               },
               "status" => %{
                 "total_agent_count" => 0
               }
             }
    end

    test "returns 404 for agent type that does not exist" do
      assert {404, _} = describe_agent_type("s1-sh-router-test-describe-2", @user_id)
    end
  end

  describe "DELETE /self_hosted_agent_types/:name" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.manage")
        )
      end)

      delete_agent_type("s1-sh-router-test-delete-1", @user_id, 401, false)
    end

    test "returns 200 and deletes existing agent type" do
      # agent type exists
      SelfHostedAgent.create(@org_id, "s1-sh-router-test-delete-1", @user_id)
      assert {200, _} = describe_agent_type("s1-sh-router-test-delete-1", @user_id)

      # agent type is deleted and no longer exists
      delete_agent_type("s1-sh-router-test-delete-1", @user_id, 200)
      assert {404, _} = describe_agent_type("s1-sh-router-test-delete-1", @user_id)
    end

    test "returns 404 for agent type that does not exist" do
      delete_agent_type("s1-sh-router-test-delete-does-not-exist", @user_id, 404)
    end
  end

  describe "POST /self_hosted_agent_types/:name/disable_all" do
    test "unauthorized user" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.self_hosted_agents.manage")
        )
      end)

      delete_agent_type("s1-sh-router-test-disable-all-1", @user_id, 401, false)
    end

    test "returns 200 and disables idle agents" do
      agent_type = "s1-sh-router-test-disable-all-2"
      SelfHostedAgent.create(@org_id, agent_type, @user_id)
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
      disable_all_agents(agent_type, params, @user_id, 200)

      # only the 2 idle agents are disabled
      assert 2 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end

    test "returns 200 and disables all agents" do
      agent_type = "s1-sh-router-test-disable-all-3"
      SelfHostedAgent.create(@org_id, agent_type, @user_id)
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
      disable_all_agents(agent_type, params, @user_id, 200)

      # only the 2 idle agents are disabled
      assert 3 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end

    test "returns 400 on bad argument" do
      agent_type = "s1-sh-router-test-disable-all-4"
      SelfHostedAgent.create(@org_id, agent_type, @user_id)

      params = %{"only_idle" => "this-is-not-valid"}

      assert "Invalid 'only_idle': 'this-is-not-valid' is not a boolean." ==
               disable_all_agents(agent_type, params, @user_id, 400)
    end
  end

  defp create_agent_type(args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types"

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.post(url, Poison.encode!(args), headers(user_id))

    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp update_agent_type(name, args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.patch(url, Poison.encode!(args), headers(user_id))

    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp disable_all_agents(name, args, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name <> "/disable_all"

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.post(url, Poison.encode!(args), headers(user_id))

    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp delete_agent_type(name, user_id, expected_status_code, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> name
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.delete(url, headers(user_id))
    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp list_agent_types(user_id, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types"
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp describe_agent_type(agent_type_name, user_id, decode? \\ true) do
    url = "localhost:4004/self_hosted_agent_types/" <> agent_type_name
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", @org_id}
    ]
end
