defmodule Front.FeatureHubProvider do
  use FeatureProvider.Provider
  alias Front.Clients.Feature, as: FeatureClient

  alias InternalApi.Feature.{
    Availability,
    Machine,
    OrganizationFeature,
    Feature,
    OrganizationMachine
  }

  import Front.Utils

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts \\ [])

  def provide_features(nil, _opts) do
    %InternalApi.Feature.ListFeaturesRequest{}
    |> FeatureClient.list_features()
    |> unwrap(fn response ->
      features =
        response.features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.visible?/1)

      ok(features)
    end)
  end

  def provide_features(org_id, _opts) do
    FeatureClient.list_organization_features(%{org_id: org_id})
    |> unwrap(fn response ->
      features =
        response.organization_features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.visible?/1)

      ok(features)
    end)
  end

  @impl FeatureProvider.Provider
  def provide_machines(org_id, _opts \\ []) do
    FeatureClient.list_organization_machines(%{org_id: org_id})
    |> unwrap(fn response ->
      machines =
        response.organization_machines
        |> Enum.map(&machine_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Machine.enabled?/1)
        |> order_by_machine_type()

      ok(machines)
    end)
  end

  defp feature_from_grpc(%Feature{
         availability: availability,
         name: name,
         type: type,
         description: description
       }) do
    %FeatureProvider.Feature{
      name: name,
      type: type,
      description: description,
      quantity: quantity_from_availability(availability),
      state: state_from_availability(availability)
    }
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
    |> Availability.State.key()
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
