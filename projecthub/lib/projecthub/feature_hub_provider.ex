defmodule Projecthub.FeatureHubProvider do
  import Toolkit
  use FeatureProvider.Provider
  alias Projecthub.Workers.AgentStore

  alias InternalApi.Feature.{
    OrganizationFeature,
    Feature,
    Availability
  }

  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()

  @impl FeatureProvider.Provider
  def provide_features(nil, opts) do
    use_cache? = Keyword.get(opts, :use_cache, true)

    if use_cache? do
      cache_fetch("", "organization_features", fn ->
        do_list_features(update_cache: true)
      end)
    else
      do_list_features()
    end
  end

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts) do
    use_cache? = Keyword.get(opts, :use_cache, true)

    if use_cache? do
      cache_fetch(org_id, "list_organization_features", fn ->
        do_list_organization_features(org_id, update_cache: true)
      end)
    else
      do_list_organization_features(org_id)
    end
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts) do
    wrap([])
  end

  defp cache_fetch(org_id, operation, callback) do
    cache_key = cache_key(org_id, operation)

    AgentStore.get(:feature_store, cache_key, item_ttl_ms: :timer.minutes(15))
    |> case do
      :not_found ->
        Watchman.increment({"feature_hub.#{operation}.cache_miss", [org_id]})
        callback.()

      {:expired, results} ->
        Watchman.increment({"feature_hub.#{operation}.cache_miss", [org_id]})

        callback.()
        |> case do
          {:error, _} -> wrap(results)
          _ -> wrap(results)
        end

      results ->
        Watchman.increment({"feature_hub.#{operation}.cache_hit", [org_id]})
        wrap(results)
    end
  end

  defp cache_key(org_id, operation),
    do: "feature_hub/#{@cache_version}/#{org_id}/#{operation}"

  defp do_list_organization_features(org_id, opts \\ []) do
    update_cache = Keyword.get(opts, :update_cache, false)

    Projecthub.FeatureHubClient.list_organization_features(%{org_id: org_id})
    |> unwrap(fn response ->
      features =
        response.organization_features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.enabled?/1)

      if update_cache do
        cache_key = cache_key(org_id, "list_organization_features")
        AgentStore.store(:feature_store, cache_key, features)
      end

      wrap(features)
    end)
  end

  defp do_list_features(opts \\ []) do
    update_cache = Keyword.get(opts, :update_cache, false)

    Projecthub.FeatureHubClient.list_features(%{})
    |> unwrap(fn response ->
      features =
        response.features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.enabled?/1)

      if update_cache do
        cache_key = cache_key("", "list_features")
        AgentStore.store(:feature_store, cache_key, features)
      end

      wrap(features)
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
end
