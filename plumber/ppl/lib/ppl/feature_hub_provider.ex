defmodule Ppl.FeatureHubProvider do
  @moduledoc """
  `FeatureProvider.Provider` implementation backed by the Feature (FeatureHub)
  gRPC API.

  Only organization features are needed in plumber; machines are not used here.
  On any error fetching features we return `{:error, _}`, which makes
  `FeatureProvider.feature_enabled?/2` fail closed (return `false`).
  """

  use FeatureProvider.Provider

  alias Ppl.FeatureClient
  alias InternalApi.Feature.{Availability, OrganizationFeature}

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts \\ []) do
    case FeatureClient.list_organization_features(org_id) do
      {:ok, organization_features} ->
        features =
          organization_features
          |> Enum.map(&feature_from_grpc/1)
          |> Enum.filter(&FeatureProvider.Feature.visible?/1)

        {:ok, features}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts \\ []) do
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

  defp quantity_from_availability(%Availability{quantity: quantity}), do: quantity
  defp quantity_from_availability(_), do: 0

  defp state_from_availability(%Availability{state: state}) do
    state
    |> Availability.State.key()
    |> case do
      :ENABLED -> :enabled
      :HIDDEN -> :disabled
      :ZERO_STATE -> :zero_state
    end
  end

  defp state_from_availability(_), do: :disabled
end
