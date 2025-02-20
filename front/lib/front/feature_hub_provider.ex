defmodule Front.FeatureHubProvider do
  use FeatureProvider.Provider
  alias Front.Clients.Feature, as: FeatureClient

  alias InternalApi.Feature.{
    Availability,
    Machine,
    OrganizationFeature,
    OrganizationMachine
  }

  import Front.Utils

  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()

  defp cache_key(org_id, operation),
    do: "feature_hub/#{@cache_version}/#{org_id}/#{operation}"

  @impl FeatureProvider.Provider
  def list_features(org_id, opts \\ []) do
    use_cache? = Keyword.get(opts, :use_cache, true)

    if use_cache? do
      cache_fetch(org_id, "list_organization_features", fn ->
        do_list_features(org_id, update_cache: true)
      end)
    else
      do_list_features(org_id)
    end
  end

  @impl FeatureProvider.Provider
  def list_machines(org_id, opts \\ []) do
    use_cache? = Keyword.get(opts, :use_cache, true)

    if use_cache? do
      cache_fetch(org_id, "list_organization_machines", fn ->
        do_list_machines(org_id, update_cache: true)
      end)
    else
      do_list_machines(org_id)
    end
  end

  defp cache_fetch(org_id, operation, callback) do
    cache_key(org_id, operation)
    |> Front.Cache.get()
    |> case do
      {:ok, results} ->
        Watchman.increment({"feature_hub.#{operation}.cache_hit", [org_id]})
        ok(Front.Cache.decode(results))

      {:not_cached, _} ->
        Watchman.increment({"feature_hub.#{operation}.cache_miss", [org_id]})
        callback.()
    end
  end

  defp do_list_features(org_id, opts \\ []) do
    update_cache = Keyword.get(opts, :update_cache, false)

    FeatureClient.list_organization_features(%{org_id: org_id})
    |> unwrap(fn response ->
      features =
        response.organization_features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.visible?/1)

      if update_cache do
        Front.Async.run(fn ->
          cache_key(org_id, "list_organization_features")
          |> Front.Cache.set(Front.Cache.encode(features), cache_ttl())
        end)
      end

      ok(features)
    end)
  end

  defp do_list_machines(org_id, opts \\ []) do
    update_cache = Keyword.get(opts, :update_cache, false)

    FeatureClient.list_organization_machines(%{org_id: org_id})
    |> unwrap(fn response ->
      machines =
        response.organization_machines
        |> Enum.map(&machine_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Machine.enabled?/1)
        |> order_by_machine_type()

      if update_cache do
        Front.Async.run(fn ->
          cache_key(org_id, "list_organization_machines")
          |> Front.Cache.set(Front.Cache.encode(machines), cache_ttl())
        end)
      end

      ok(machines)
    end)
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

  defp cache_ttl do
    Application.get_env(:front, :cache_settings)[:features_ttl]
  end
end
