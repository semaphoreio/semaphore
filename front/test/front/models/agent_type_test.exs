defmodule Front.Models.AgentTypeTest do
  use Front.TestCase
  doctest Front.Models.AgentType
  alias Front.Models.AgentType

  setup do
    org_id = Ecto.UUID.generate()
    empty_agents_org_id = Ecto.UUID.generate()

    Support.Stubs.Feature.set_org_defaults(org_id)

    [
      org_id: org_id,
      empty_agents_org_id: empty_agents_org_id
    ]
  end

  describe "list" do
    test "fetches list of agents for given organization", %{org_id: org_id} do
      {:ok, agent_type_list} = AgentType.list(org_id)

      assert %{
               default_linux_os_image: "ubuntu2204",
               default_mac_os_image: "macos-xcode13"
             } = agent_type_list

      assert length(agent_type_list.agent_types) == 16

      available_machines =
        agent_type_list.agent_types
        |> Enum.map(& &1.type)
        |> Enum.uniq()

      assert ["a1-standard-4", "a1-standard-8", "e1-standard-2", "e1-standard-4", "e1-standard-8"] ==
               available_machines

      linux_os_images =
        agent_type_list.agent_types
        |> Enum.filter(&(&1.platform == "LINUX"))
        |> Enum.map(& &1.os_image)
        |> Enum.uniq()
        |> Enum.sort()

      assert linux_os_images == ["ubuntu1804", "ubuntu2004", "ubuntu2204", "ubuntu2404"]
    end

    test "list is empty if there are no agents available", %{empty_agents_org_id: org_id} do
      {:ok, agent_type_list} = AgentType.list(org_id)

      assert %{
               default_linux_os_image: "",
               default_mac_os_image: "",
               agent_types: []
             } == agent_type_list
    end
  end
end
