defmodule Secrethub.FeatureHubProvider do
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
  def list_features(org_id, opts) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(15))
    cache_key = cache_key(org_id, "list_organization_features")

    Cachex.fetch(:feature_cache, cache_key, fn ->
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
        Cachex.expire(:feature_cache, cache_key, ttl)
        {:ok, features}

      {:ignore, _} ->
        {:ok, []}

      _ ->
        {:ok, []}
    end
  end

  @impl FeatureProvider.Provider
  def list_machines(_org_id, _) do
    {:ok, []}
  end

  def do_list_features(org_id) do
    alias InternalApi.Feature.ListOrganizationFeaturesRequest, as: Request
    alias InternalApi.Feature.FeatureService.Stub

    Watchman.benchmark("feature_hub.list_organization_features.duration", fn ->
      req = Request.new(org_id: org_id)

      {:ok, ep} = Application.fetch_env(:secrethub, :feature_api_endpoint)

      {:ok, ch} = GRPC.Stub.connect(ep)

      Logger.debug("Listing features for org #{org_id} from GRPC endpoint #{inspect(ep)}")

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

          {:ok, []}
      end
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
