defmodule PipelinesAPI.SelfHostedHubClient.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.SelfHostedHubClient
  alias Support.Stubs.SelfHostedAgent

  @org_id "test_org"
  @user_id "test_user"

  setup do
    Support.Stubs.reset()
  end

  describe ".create" do
    test "creates agent type" do
      conn = create_conn()
      params = %{"metadata" => %{"name" => "s1-client-test"}}

      assert {:ok, response} = SelfHostedHubClient.create(params, conn)
      assert response.metadata.name == "s1-client-test"
      assert response.metadata.create_time == 1_668_202_871
      assert response.metadata.update_time == 1_668_202_871

      assert response.status.total_agent_count == 0
      assert response.status.registration_token != ""
    end

    test "does not create agent type if name is not provided" do
      assert {:error, {:user, message}} = SelfHostedHubClient.create(%{}, create_conn())
      assert message == "Name must be provided"
    end

    test "does not create agent type if already exists" do
      params = %{"metadata" => %{"name" => "s1-client-test-2"}}

      # agent type is created
      assert {:ok, _response} = SelfHostedHubClient.create(params, create_conn())

      # agent type is not created, because it already exists
      assert {:error, {:user, message}} = SelfHostedHubClient.create(params, create_conn())
      assert message == "The agent type with name 's1-client-test-2' already exists"
    end

    test "does not create agent type if name isn't allowed" do
      params = %{"metadata" => %{"name" => "e1-bad-prefix"}}
      assert {:error, {:user, message}} = SelfHostedHubClient.create(params, create_conn())
      assert message == "The agent type name 'e1-bad-prefix' is not allowed"
    end

    test "internal error if self-hosted-hub can't be reached" do
      System.put_env("SELF_HOSTED_HUB_URL", "something:12345")

      params = %{"metadata" => %{"name" => "my-agent-type"}}
      assert {:error, {:internal, message}} = SelfHostedHubClient.create(params, create_conn())
      assert message == "Internal error"

      System.put_env("SELF_HOSTED_HUB_URL", "127.0.0.1:50052")
    end
  end

  describe ".describe" do
    test "existing agent type" do
      SelfHostedAgent.create(@org_id, "s1-describe-test", @user_id)

      params = %{"agent_type_name" => "s1-describe-test"}
      assert {:ok, response} = SelfHostedHubClient.describe(params, create_conn())

      assert response == %{
               metadata: %{
                 name: "s1-describe-test",
                 create_time: 1_668_202_871,
                 update_time: 1_668_202_871
               },
               status: %{
                 total_agent_count: 0
               },
               spec: %{
                 agent_name_settings: %{
                   assignment_origin: "assignment_origin_agent",
                   aws: nil,
                   release_after: 0
                 }
               }
             }
    end

    test "non-existing agent type" do
      params = %{"agent_type_name" => "s1-describe-test-not-found"}
      assert {:error, {:not_found, _}} = SelfHostedHubClient.describe(params, create_conn())
    end
  end

  describe ".describe_agent" do
    test "existing agent" do
      SelfHostedAgent.create(@org_id, "s1-describe-agent-test", @user_id)
      SelfHostedAgent.add_agent(@org_id, "s1-describe-agent-test", "my-agent-1")

      params = %{"agent_name" => "my-agent-1"}
      assert {:ok, response} = SelfHostedHubClient.describe_agent(params, create_conn())

      assert response == %{
               metadata: %{
                 name: "my-agent-1",
                 type: "s1-describe-agent-test",
                 version: "v1.5.9",
                 connected_at: 1_668_202_871,
                 os: "Ubuntu 14.04.5 LTS",
                 arch: "x86_64",
                 hostname: "boxbox",
                 ip_address: "182.92.12.1",
                 pid: 90
               },
               status: %{
                 state: "waiting_for_job"
               }
             }
    end

    test "non-existing agent" do
      params = %{"agent_name" => "this-agent-does-not-exist"}
      assert {:error, {:not_found, _}} = SelfHostedHubClient.describe_agent(params, create_conn())
    end
  end

  describe ".list" do
    test "empty list" do
      assert {:ok, response} = SelfHostedHubClient.list(%{}, create_conn())
      assert response.agent_types == []
    end

    test "returns list of agent types" do
      SelfHostedAgent.create(@org_id, "s1-list-test", @user_id)
      SelfHostedAgent.create(@org_id, "s1-list-test-2", @user_id)
      SelfHostedAgent.create(@org_id, "s1-list-test-3", @user_id)

      # agent types are listed
      assert {:ok, response} = SelfHostedHubClient.list(%{}, create_conn())

      assert response.agent_types == [
               %{
                 metadata: %{
                   name: "s1-list-test",
                   create_time: 1_668_202_871,
                   update_time: 1_668_202_871
                 },
                 status: %{
                   total_agent_count: 0
                 },
                 spec: %{
                   agent_name_settings: %{
                     assignment_origin: "assignment_origin_agent",
                     aws: nil,
                     release_after: 0
                   }
                 }
               },
               %{
                 metadata: %{
                   name: "s1-list-test-2",
                   create_time: 1_668_202_871,
                   update_time: 1_668_202_871
                 },
                 status: %{
                   total_agent_count: 0
                 },
                 spec: %{
                   agent_name_settings: %{
                     assignment_origin: "assignment_origin_agent",
                     aws: nil,
                     release_after: 0
                   }
                 }
               },
               %{
                 metadata: %{
                   name: "s1-list-test-3",
                   create_time: 1_668_202_871,
                   update_time: 1_668_202_871
                 },
                 status: %{
                   total_agent_count: 0
                 },
                 spec: %{
                   agent_name_settings: %{
                     assignment_origin: "assignment_origin_agent",
                     aws: nil,
                     release_after: 0
                   }
                 }
               }
             ]
    end
  end

  describe ".list_agents" do
    test "empty list" do
      assert {:ok, response} = SelfHostedHubClient.list_agents(%{}, create_conn())
      assert response.agents == []
    end

    test "returns agents" do
      SelfHostedAgent.create(@org_id, "s1-list-agents-test", @user_id)
      SelfHostedAgent.add_agent(@org_id, "s1-list-agents-test", "agent-1")
      SelfHostedAgent.add_agent(@org_id, "s1-list-agents-test", "agent-2")

      SelfHostedAgent.create(@org_id, "s1-list-agents-test-2", @user_id)
      SelfHostedAgent.add_agent(@org_id, "s1-list-agents-test-2", "agent-3")

      # all agents are listed
      assert {:ok, response} = SelfHostedHubClient.list_agents(%{}, create_conn())

      assert response.agents == [
               %{
                 metadata: %{
                   name: "agent-1",
                   type: "s1-list-agents-test",
                   connected_at: 1_668_202_871,
                   version: "v1.5.9",
                   os: "Ubuntu 14.04.5 LTS",
                   arch: "x86_64",
                   hostname: "boxbox",
                   ip_address: "182.92.12.1",
                   pid: 90
                 },
                 status: %{
                   state: "waiting_for_job"
                 }
               },
               %{
                 metadata: %{
                   name: "agent-2",
                   type: "s1-list-agents-test",
                   connected_at: 1_668_202_871,
                   version: "v1.5.9",
                   os: "Ubuntu 14.04.5 LTS",
                   arch: "x86_64",
                   hostname: "boxbox",
                   ip_address: "182.92.12.1",
                   pid: 90
                 },
                 status: %{
                   state: "waiting_for_job"
                 }
               },
               %{
                 metadata: %{
                   name: "agent-3",
                   type: "s1-list-agents-test-2",
                   connected_at: 1_668_202_871,
                   version: "v1.5.9",
                   os: "Ubuntu 14.04.5 LTS",
                   arch: "x86_64",
                   hostname: "boxbox",
                   ip_address: "182.92.12.1",
                   pid: 90
                 },
                 status: %{
                   state: "waiting_for_job"
                 }
               }
             ]

      # Only agents for a single type are listed
      params = %{"agent_type" => "s1-list-agents-test-2"}
      assert {:ok, response} = SelfHostedHubClient.list_agents(params, create_conn())

      assert response.agents == [
               %{
                 metadata: %{
                   name: "agent-3",
                   type: "s1-list-agents-test-2",
                   connected_at: 1_668_202_871,
                   version: "v1.5.9",
                   os: "Ubuntu 14.04.5 LTS",
                   arch: "x86_64",
                   hostname: "boxbox",
                   ip_address: "182.92.12.1",
                   pid: 90
                 },
                 status: %{
                   state: "waiting_for_job"
                 }
               }
             ]
    end
  end

  describe ".delete" do
    test "not found agent type" do
      params = %{"agent_type_name" => "s1-delete-test-not-found"}
      assert {:error, {:not_found, _}} = SelfHostedHubClient.delete(params, create_conn())
    end

    test "existing agent type" do
      SelfHostedAgent.create(@org_id, "s1-delete-test", @user_id)

      # agent type can be described
      params = %{"agent_type_name" => "s1-delete-test"}
      assert {:ok, _} = SelfHostedHubClient.describe(params, create_conn())

      # agent type is deleted and can no longer be described
      assert {:ok, _} = SelfHostedHubClient.delete(params, create_conn())
      assert {:error, {:not_found, _}} = SelfHostedHubClient.describe(params, create_conn())
    end
  end

  describe ".disable_all" do
    test "idle agents only" do
      agent_type = "s1-disable-all-test"
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

      params = %{"agent_type_name" => agent_type, "only_idle" => true}
      assert {:ok, _} = SelfHostedHubClient.disable_all(params, create_conn())

      # only the 2 idle agents are disabled
      assert 2 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, "s1-disable-all-test"),
                 fn agent -> agent.disabled_at != nil end
               )
    end

    test "all agents" do
      agent_type = "s1-disable-all-test-2"
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

      params = %{"agent_type_name" => agent_type, "only_idle" => false}
      assert {:ok, _} = SelfHostedHubClient.disable_all(params, create_conn())

      # all the agents are disabled
      assert 3 ==
               Enum.count(
                 SelfHostedAgent.list_agents(@org_id, agent_type),
                 fn agent -> agent.disabled_at != nil end
               )
    end
  end

  # Utility

  defp create_conn() do
    init_conn()
    |> put_req_header("x-semaphore-user-id", @user_id)
    |> put_req_header("x-semaphore-org-id", @org_id)
  end

  defp init_conn() do
    conn(:get, "/self_hosted_agent_types/s1-whatever")
  end
end
