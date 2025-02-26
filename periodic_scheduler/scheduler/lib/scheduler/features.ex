defmodule Scheduler.FeatureHubProvider do
  @moduledoc false
  use FeatureProvider.Provider
  require Logger

  alias InternalApi.Feature.{
    OrganizationFeature,
    Availability
  }

  defp url(), do: Application.get_env(:scheduler, :feature_api_grpc_endpoint)

  @impl FeatureProvider.Provider
  def provide_features(org_id, opts) do
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

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _) do
    {:ok, []}
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
