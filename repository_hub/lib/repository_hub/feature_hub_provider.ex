defmodule RepositoryHub.FeatureHubProvider do
  use FeatureProvider.Provider
  alias RepositoryHub.FeatureClient

  alias InternalApi.Feature.{
    OrganizationFeature,
    Availability
  }

  import RepositoryHub.Toolkit

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts \\ []) do
    FeatureClient.list_organization_features(org_id)
    |> unwrap(fn response ->
      features =
        response.organization_features
        |> Enum.map(&feature_from_grpc/1)
        |> Enum.filter(&FeatureProvider.Feature.visible?/1)

      wrap(features)
    end)
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts \\ []) do
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
