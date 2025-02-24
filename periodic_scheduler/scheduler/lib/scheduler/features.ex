defmodule Scheduler.FeatureHubProvider do
  @moduledoc false
  use FeatureProvider.Provider
  require Logger

  @cache_key Elixir.Scheduler.FeatureHubProvider

  alias InternalApi.Feature.{
    OrganizationFeature,
    Availability
  }

  @namespace "scheduler.feature_provider"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()

  defp url(), do: Application.get_env(:scheduler, :feature_api_grpc_endpoint)

  defp cache_key(org_id, operation),
    do: "#{@namespace}/#{@cache_version}/#{org_id}/#{operation}"

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(15))
    cache_key = cache_key(org_id, "list_organization_features")

    Cachex.fetch(@cache_key, cache_key, fn ->
      do_list_features(org_id)
      |> case do
        {:ok, features} ->
          {:commit, features}

        _err ->
          {:ignore, []}
      end
    end)
    |> case do
      {:commit, features} ->
        Cachex.expire(@cache_key, cache_key, ttl)
        {:ok, features}

      {:ok, features} ->
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
    alias InternalApi.Feature.FeatureService.Stub

    Watchman.benchmark("scheduler.feature_hub.list_organization_features.duration", fn ->
      req = Request.new(org_id: org_id)

      {:ok, ch} = GRPC.Stub.connect(url())

      Stub.list_organization_features(ch, req, timeout: 3_000)
      |> case do
        ret = {:ok, _res} ->
          Watchman.increment({"scheduler.feature_hub.list_organization_features.success", []})
          ret

        res = {:error, _} ->
          Watchman.increment({"scheduler.feature_hub.list_organization_features.error", []})
          res
      end
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
