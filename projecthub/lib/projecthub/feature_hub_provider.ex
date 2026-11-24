defmodule Projecthub.FeatureHubProvider do
  import Toolkit
  use FeatureProvider.Provider

  alias InternalApi.Feature.{
    OrganizationFeature,
    Feature,
    Availability
  }

  @impl FeatureProvider.Provider
  def provide_features(nil, _opts) do
    Projecthub.FeatureHubClient.list_features(%{})
    |> unwrap(fn response ->
      response.features
      |> Enum.map(&feature_from_grpc/1)
      |> Enum.filter(&FeatureProvider.Feature.enabled?/1)
      |> wrap()
    end)
  end

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts) do
    Projecthub.FeatureHubClient.list_organization_features(%{org_id: org_id})
    |> unwrap(fn response ->
      response.organization_features
      |> Enum.map(&feature_from_grpc/1)
      |> Enum.filter(&FeatureProvider.Feature.enabled?/1)
      |> wrap()
    end)
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts) do
    wrap([])
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
