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
    FeatureProvider.list_machines(param: org_id)
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

defmodule Front.Models.AgentTypeSanitizer do
  @deprecated_linux_os_images ["ubuntu1804", "ubuntu2004"]
  @preferred_linux_os_images ["ubuntu2404", "ubuntu2204"]

  @spec sanitize_hosted_agent_types(%{
          required(:agent_types) => [map()],
          optional(:default_linux_os_image) => String.t()
        }) :: map()
  def sanitize_hosted_agent_types(hosted_agent_types) do
    hosted_agent_types
    |> filter_out_deprecated_linux_images()
    |> update_default_linux_os_image()
  end

  defp filter_out_deprecated_linux_images(hosted_agent_types) do
    filtered_agent_types =
      hosted_agent_types.agent_types
      |> Enum.reject(fn agent_type ->
        agent_type.platform == "LINUX" and agent_type.os_image in @deprecated_linux_os_images
      end)

    %{hosted_agent_types | agent_types: filtered_agent_types}
  end

  defp update_default_linux_os_image(hosted_agent_types) do
    available_linux_os_images =
      hosted_agent_types.agent_types
      |> Enum.filter(&(&1.platform == "LINUX"))
      |> Enum.map(& &1.os_image)
      |> Enum.uniq()

    default_linux_os_image =
      hosted_agent_types.default_linux_os_image
      |> resolve_default_linux_os_image(available_linux_os_images)

    %{hosted_agent_types | default_linux_os_image: default_linux_os_image}
  end

  defp resolve_default_linux_os_image(default_linux_os_image, available_linux_os_images)
       when default_linux_os_image in @deprecated_linux_os_images,
       do: fallback_linux_os_image(available_linux_os_images)

  defp resolve_default_linux_os_image(default_linux_os_image, available_linux_os_images) do
    if default_linux_os_image in available_linux_os_images do
      default_linux_os_image
    else
      fallback_linux_os_image(available_linux_os_images)
    end
  end

  defp fallback_linux_os_image(available_linux_os_images) do
    Enum.find(@preferred_linux_os_images, &(&1 in available_linux_os_images)) ||
      List.first(available_linux_os_images) ||
      ""
  end
end
