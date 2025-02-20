defmodule E2E.API.AgentsTest do
  use ExUnit.Case, async: true
  alias E2E.Clients.Agent

  @default_agent_type_name "s1-test-type"

  describe "Agent Types API" do
    test "full agent type lifecycle" do
      agent_type_name = "#{@default_agent_type_name}-#{:rand.uniform(1000)}"
      # Create an agent type
      agent_type_params = %{
        "metadata" => %{
          "name" => agent_type_name
        },
        "spec" => %{
          "agent_name_settings" => %{
            "assignment_origin" => "assignment_origin_agent",
            "release_after" => 0
          }
        }
      }

      {:ok, create_response} = Agent.create_type(agent_type_params)
      assert create_response.status_code == 200

      created_type = Jason.decode!(create_response.body)
      assert created_type["metadata"]["name"] == agent_type_name

      # List agent types and verify our type exists
      {:ok, list_response} = Agent.list_types()
      assert list_response.status_code == 200

      agent_types = Jason.decode!(list_response.body)["agent_types"]
      assert Enum.any?(agent_types, fn t -> t["metadata"]["name"] == agent_type_name end)

      # Get specific agent type
      {:ok, get_response} = Agent.get_type(agent_type_name)
      assert get_response.status_code == 200

      agent_type = Jason.decode!(get_response.body)
      assert agent_type["metadata"]["name"] == agent_type_name

      assert agent_type["spec"]["agent_name_settings"]["assignment_origin"] ==
               "assignment_origin_agent"

      # Update agent type
      updated_params =
        put_in(
          agent_type_params,
          ["spec", "agent_name_settings", "release_after"],
          60
        )

      {:ok, update_response} = Agent.update_type(agent_type_name, updated_params)
      assert update_response.status_code == 200

      updated_type = Jason.decode!(update_response.body)
      assert updated_type["spec"]["agent_name_settings"]["release_after"] == 60

      # Disable agents for type
      {:ok, _} = Agent.disable_agents(agent_type_name)

      # Delete agent type
      {:ok, _} = Agent.delete_type(agent_type_name)

      # Verify type is gone
      {:ok, final_list_response} = Agent.list_types()
      assert final_list_response.status_code == 200

      final_types = Jason.decode!(final_list_response.body)["agent_types"]
      refute Enum.any?(final_types, fn t -> t["metadata"]["name"] == agent_type_name end)
    end

    test "handles non-existent agent type" do
      non_existent_name = "non-existent-#{:rand.uniform(1000)}"
      {:ok, response} = Agent.get_type(non_existent_name)
      assert response.status_code == 404
      assert response.body =~ "agent type not found"
    end
  end

  describe "Agents API" do
    test "list and get agents with default page size" do
      # List all agents
      {:ok, list_response} = Agent.list()
      assert list_response.status_code == 200

      agents = Jason.decode!(list_response.body)["agents"]
      assert is_list(agents)
    end

    test "list and get agents with custom page size" do
      # List with pagination
      {:ok, paged_response} = Agent.list(%{"page_size" => 10})
      assert paged_response.status_code == 200

      paged_agents = Jason.decode!(paged_response.body)
      assert length(paged_agents["agents"]) <= 10

      if length(paged_agents["agents"]) > 0 do
        # Get specific agent
        agent_name = hd(paged_agents["agents"])["metadata"]["name"]
        {:ok, get_response} = Agent.get(agent_name)
        agent = Jason.decode!(get_response.body)
        assert agent["metadata"]["name"] == agent_name
      end
    end

    test "handles non-existent agent" do
      non_existent_name = "non-existent-#{:rand.uniform(1000)}"
      {:ok, response} = Agent.get(non_existent_name)
      assert response.status_code == 404
      assert response.body =~ "agent not found"
    end
  end
end
