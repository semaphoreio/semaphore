defmodule Auth.FeatureHubProvider do
  use FeatureProvider.Provider
  require Logger
  alias Auth.FeatureClient

  alias InternalApi.Feature.{
    OrganizationFeature,
    OrganizationMachine,
    Availability,
    Machine
  }

  defp cache_key(org_id, operation),
    do: "feature_hub/#{org_id}/#{operation}"

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts \\ []) do
    Auth.Cache.fetch!(cache_key(org_id, "list_organization_features"), :timer.minutes(5), fn ->
      do_list_features(org_id)
    end)
  end

  @impl FeatureProvider.Provider
  def provide_machines(org_id, _opts \\ []) do
    Auth.Cache.fetch!(cache_key(org_id, "list_organization_machines"), :timer.minutes(5), fn ->
      do_list_machines(org_id)
    end)
  end

  defp do_list_features(org_id) do
    case FeatureClient.list_organization_features(org_id) do
      {:ok, response} ->
        features =
          response.organization_features
          |> Enum.map(&feature_from_grpc/1)
          |> Enum.filter(&FeatureProvider.Feature.visible?/1)

        {:ok, features}

      e ->
        Logger.error("Error listing features for #{org_id}: #{inspect(e)}")
        e
    end
  end

  defp do_list_machines(org_id) do
    case FeatureClient.list_organization_machines(org_id) do
      {:ok, response} ->
        machines =
          response.organization_machines
          |> Enum.map(&machine_from_grpc/1)
          |> Enum.filter(&FeatureProvider.Machine.enabled?/1)
          |> order_by_machine_type()

        {:ok, machines}

      e ->
        Logger.error("Error listing machines for #{org_id}: #{inspect(e)}")
        e
    end
  end

  defp feature_from_grpc(%OrganizationFeature{feature: feature, availability: availability}) do
    %FeatureProvider.Feature{
      name: feature.name,
      type: feature.type,
      description: feature.description,
      quantity: quantity_from_availability(availability),
      state: state_from_availability(availability)
    }
  end

  defp machine_from_grpc(%OrganizationMachine{machine: machine, availability: availability}) do
    %FeatureProvider.Machine{
      type: machine.type,
      platform: "#{Machine.Platform.key(machine.platform)}",
      vcpu: machine.vcpu,
      ram: machine.ram,
      disk: machine.disk,
      default_os_image: machine.default_os_image,
      available_os_images: machine.os_images,
      quantity: quantity_from_availability(availability),
      state: state_from_availability(availability)
    }
  end

  defp quantity_from_availability(%Availability{quantity: quantity}) do
    quantity
  end

  defp state_from_availability(%Availability{state: state}) do
    state
    |> case do
      :ENABLED -> :enabled
      :HIDDEN -> :disabled
      :ZERO_STATE -> :zero_state
    end
  end

  @spec order_by_machine_type([Machine.t()]) :: [Machine.t()]
  defp order_by_machine_type(machines) do
    machines
    |> Enum.sort_by(fn %{type: type} ->
      type
      |> String.split("-", parts: 2)
    end)
  end
end
