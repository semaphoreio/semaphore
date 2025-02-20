defmodule Front.Models.AgentType do
  require Logger
  alias __MODULE__

  defstruct [:type, :platform, :specs, :os_image, :state]

  @type t :: %AgentType{
          type: String.t(),
          platform: String.t(),
          specs: String.t(),
          os_image: String.t(),
          state: String.t()
        }

  @type agent_listing :: %{
          agent_types: [t()],
          default_mac_os_image: String.t(),
          default_linux_os_image: String.t()
        }

  @spec list(org_id :: String.t()) :: {:ok, agent_listing()}
  def list(org_id) do
    FeatureProvider.list_machines(org_id)
    |> case do
      {:ok, machines} -> machines
      _ -> []
    end
    |> then(fn machines ->
      agents = build_agent_listing(machines)
      mac_image = machines |> find_default_image("MAC")
      linux_image = machines |> find_default_image("LINUX")

      {:ok,
       %{
         agent_types: agents,
         default_mac_os_image: mac_image,
         default_linux_os_image: linux_image
       }}
    end)
  end

  @spec build_agent_listing(machines :: [FeatureProvider.Machine.t()]) :: [t()]
  def build_agent_listing(machines) do
    for machine <- machines, image <- machine.available_os_images do
      %AgentType{
        type: machine.type,
        platform: machine.platform,
        specs: "#{machine.vcpu} vCPU, #{machine.ram} GB RAM, #{machine.disk} GB SSD",
        os_image: image,
        state: "#{machine.state}"
      }
    end
  end

  @spec find_default_image(
          machines :: [FeatureProvider.Machine.t()],
          platform :: String.t()
        ) :: String.t()
  defp find_default_image(machines, platform) do
    machines
    |> Enum.find(%{}, &(&1.platform == platform))
    |> Map.get(:default_os_image, "")
  end
end
