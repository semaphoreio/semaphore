defmodule PipelinesAPI.FeatureHubProvider do
  @moduledoc false

  use FeatureProvider.Provider
  require Logger

  alias InternalApi.Feature.FeatureService.Stub

  alias InternalApi.Feature.{
    OrganizationFeature,
    OrganizationMachine,
    Availability,
    Machine,
    Feature
  }

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, opts \\ [])

  def provide_machines(nil, _opts) do
    grpc_call(
      fn channel ->
        req = InternalApi.Feature.ListMachinesRequest.new()
        Stub.list_machines(channel, req, timeout: 3_000)
      end,
      metric: "feature_hub.list_machines"
    )
    |> case do
      {:ok, response} ->
        machines =
          response.machines
          |> Enum.map(&machine_from_grpc/1)

        {:ok, machines}

      error ->
        log_error("MachineHubProvider.provide_machines", error: error)

        error
    end
  end

  def provide_machines(org_id, _opts) do
    grpc_call(
      fn channel ->
        req = InternalApi.Feature.ListOrganizationMachinesRequest.new(org_id: org_id)
        Stub.list_organization_machines(channel, req, timeout: 3_000)
      end,
      metric: "feature_hub.list_organization_machines"
    )
    |> case do
      {:ok, response} ->
        machines =
          response.organization_machines
          |> Enum.map(&machine_from_grpc/1)

        {:ok, machines}

      error ->
        log_error("MachineHubProvider.provide_machines", error: error, org_id: org_id)
    end
  end

  @impl FeatureProvider.Provider
  def provide_features(_org_id, _opts \\ [])

  def provide_features(nil, _opts) do
    grpc_call(
      fn channel ->
        req = InternalApi.Feature.ListFeaturesRequest.new()
        Stub.list_features(channel, req, timeout: 3_000)
      end,
      metric: "feature_hub.list_features"
    )
    |> case do
      {:ok, response} ->
        features =
          response.features
          |> Enum.map(&feature_from_grpc/1)

        {:ok, features}

      error ->
        log_error("FeatureHubProvider.provide_features", error: error)

        error
    end
  end

  def provide_features(org_id, _opts) do
    grpc_call(
      fn channel ->
        req = InternalApi.Feature.ListOrganizationFeaturesRequest.new(org_id: org_id)
        Stub.list_organization_features(channel, req, timeout: 3_000)
      end,
      metric: "feature_hub.list_organization_features"
    )
    |> case do
      {:ok, response} ->
        features =
          response.organization_features
          |> Enum.map(&feature_from_grpc/1)

        {:ok, features}

      error ->
        log_error("FeatureHubProvider.provide_features", error: error, org_id: org_id)
    end
  end

  defp grpc_call(cb, opts) do
    metric = Keyword.fetch!(opts, :metric)

    Watchman.benchmark("#{metric}.duration", fn ->
      connect(metric)
      |> case do
        {:ok, channel} ->
          cb.(channel)

        other ->
          other
      end
    end)
    |> case do
      {:ok, _} = result ->
        Watchman.increment("#{metric}.success")
        result

      {:error, _} = result ->
        Watchman.increment("#{metric}.failure")
        result

      result ->
        result
    end
  end

  defp connect(metric) do
    Application.fetch_env(:pipelines_api, :feature_api_endpoint)
    |> case do
      {:ok, endpoint} ->
        {:ok, endpoint}

      :error ->
        Watchman.increment("#{metric}.failure")
        {:error, "Can't fetch feature_api_endpoint"}
    end
    |> case do
      {:ok, endpoint} ->
        GRPC.Stub.connect(endpoint)

      other ->
        other
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

  defp feature_from_grpc(feature = %Feature{availability: availability}) do
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
      platform: parse_platform(machine.platform),
      vcpu: machine.vcpu,
      ram: machine.ram,
      disk: machine.disk,
      default_os_image: machine.default_os_image,
      available_os_images: machine.os_images,
      quantity: quantity_from_availability(availability),
      state: state_from_availability(availability)
    }
  end

  defp machine_from_grpc(machine = %Machine{availability: availability}) do
    %FeatureProvider.Machine{
      type: machine.type,
      platform: parse_platform(machine.platform),
      vcpu: machine.vcpu,
      ram: machine.ram,
      disk: machine.disk,
      default_os_image: machine.default_os_image,
      available_os_images: machine.os_images,
      quantity: quantity_from_availability(availability),
      state: state_from_availability(availability)
    }
  end

  defp parse_platform(platform) do
    "#{Machine.Platform.key(platform)}"
    |> String.downcase()
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

  def log_error(message, args \\ []) do
    inspected_args =
      args
      |> Enum.map_join(" ", fn {key, value} ->
        "#{inspect(key)}=#{inspect(value)}}"
      end)

    Logger.error("#{message}#fail #{inspected_args}")
  end
end
