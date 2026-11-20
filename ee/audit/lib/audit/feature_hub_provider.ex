defmodule Audit.FeatureHubProvider do
  use FeatureProvider.Provider
  require Logger

  alias InternalApi.Feature.{
    OrganizationFeature,
    Availability
  }

  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()

  defp cache_key(org_id, operation),
    do: "feature_hub/#{@cache_version}/#{org_id}/#{operation}"

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(15))
    cache_key = cache_key(org_id, "list_organization_features")

    if Keyword.get(opts, :reload, false) do
      reload_features(org_id, cache_key, ttl)
    else
      cached_features(org_id, cache_key, ttl)
    end
  end

  # A reload is requested when the organization's features have changed, so it
  # refetches them. If that fails, the cached features are kept, not replaced.
  defp reload_features(org_id, cache_key, ttl) do
    case do_list_features(org_id) do
      {:ok, features} ->
        Audit.Cache.put(cache_key, features, ttl)
        {:ok, features}

      {:error, _} ->
        cached_features(org_id, cache_key, ttl)
    end
  end

  defp cached_features(org_id, cache_key, ttl) do
    Audit.Cache.fetch(cache_key, fn ->
      do_list_features(org_id)
      |> case do
        {:ok, features} ->
          {:commit, features}

        _ ->
          {:ignore, []}
      end
    end)
    |> case do
      {:ok, features} ->
        {:ok, features}

      {:commit, features} ->
        Audit.Cache.expire(cache_key, ttl)
        {:ok, features}

      {:ignore, _} ->
        {:ok, []}

      _ ->
        {:ok, []}
    end
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _) do
    {:ok, []}
  end

  defp do_list_features(org_id) do
    alias InternalApi.Feature.ListOrganizationFeaturesRequest, as: Request

    Watchman.benchmark("feature_hub.list_organization_features.duration", fn ->
      req = Request.new(org_id: org_id)

      {:ok, ep} = Application.fetch_env(:audit, :feature_api_endpoint)

      # A failed connect is returned like a failed call, so a reload can fall
      # back to the cached features instead of raising.
      case GRPC.Stub.connect(ep) do
        {:ok, ch} ->
          list_organization_features(ch, req)

        {:error, e} ->
          Watchman.increment("feature_hub.list_organization_features.failure")
          Logger.error("Error connecting to the feature service: #{inspect(e)}")

          {:error, e}
      end
    end)
  end

  defp list_organization_features(ch, req) do
    alias InternalApi.Feature.FeatureService.Stub

    Stub.list_organization_features(ch, req, timeout: 3_000)
    |> tap(fn
      {:ok, _res} ->
        Watchman.increment("feature_hub.list_organization_features.success")

      {:error, _} ->
        Watchman.increment("feature_hub.list_organization_features.failure")
    end)
    |> case do
      {:ok, res} ->
        features =
          res.organization_features
          |> Enum.map(&feature_from_grpc/1)

        {:ok, features}

      {:error, e} ->
        Logger.error("Error fetching organization features: #{inspect(e)}")

        {:error, e}
    end
  after
    GRPC.Stub.disconnect(ch)
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
