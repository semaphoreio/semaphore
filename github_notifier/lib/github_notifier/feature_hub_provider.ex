defmodule GithubNotifier.FeatureHubProvider do
  use FeatureProvider.Provider
  require Logger

  alias InternalApi.Feature.{
    OrganizationFeature,
    Feature,
    Availability
  }

  alias InternalApi.Feature.FeatureService.Stub

  @impl FeatureProvider.Provider
  def provide_features(org_id, _opts \\ [])

  def provide_features(nil, _opts) do
    list_features()
    |> case do
      {:ok, response} ->
        response.features
        |> build_features()

      error ->
        Logger.error("FeatureHubProvider.provide_features error: #{inspect(error)}")
        error
    end
  end

  def provide_features(org_id, _opts) do
    list_organization_features(org_id)
    |> case do
      {:ok, response} ->
        response.organization_features
        |> build_features()

      error ->
        Logger.error("FeatureHubProvider.provide_features error: #{inspect(error)}")
        error
    end
  end

  defp build_features(grpc_features) do
    grpc_features
    |> Enum.map(&feature_from_grpc/1)
    |> Enum.filter(&FeatureProvider.Feature.visible?/1)
    |> then(&{:ok, &1})
  end

  defp list_organization_features(org_id) do
    opts = [timeout: 3000]

    channel()
    |> case do
      {:ok, channel} ->
        request = InternalApi.Feature.ListOrganizationFeaturesRequest.new(org_id: org_id)

        Stub.list_organization_features(channel, request, opts)

      error ->
        error
    end
  end

  defp list_features do
    opts = [timeout: 3000]

    channel()
    |> case do
      {:ok, channel} ->
        request = InternalApi.Feature.ListFeaturesRequest.new()

        Stub.list_features(channel, request, opts)

      error ->
        error
    end
  end

  @impl FeatureProvider.Provider
  def provide_machines(_org_id, _opts \\ []) do
    {:ok, []}
  end

  defp channel do
    Application.fetch_env!(:github_notifier, :feature_grpc_endpoint)
    |> GRPC.Stub.connect()
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

  defp feature_from_grpc(%Feature{availability: availability} = feature) do
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
    |> Availability.State.key()
    |> case do
      :ENABLED -> :enabled
      :HIDDEN -> :disabled
      :ZERO_STATE -> :zero_state
    end
  end
end
