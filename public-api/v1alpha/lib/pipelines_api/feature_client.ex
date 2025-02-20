defmodule PipelinesAPI.FeatureClient do
  @moduledoc """
  Module serves to call Feature Hub service to obtain features enabled for the organization
  """

  use Plug.Builder

  alias Util.Proto

  alias InternalApi.Feature.{
    ListOrganizationFeaturesRequest,
    FeatureService
  }

  alias PipelinesAPI.Util.{Log, Metrics}

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  defp url(), do: System.get_env("FEATURE_GRPC_URL")
  defp opts(), do: [{:timeout, @wormhole_timeout}]

  def has_feature_enabled?(org_id, feature_name) do
    with {:ok, %{organization_features: features}} <- get_organization_features(org_id),
         {:ok, feature} <- find_feature(features, feature_name),
         state <- feature.availability.state do
      state == :ENABLED
    else
      _ -> false
    end
  end

  defp find_feature(features, feature_name) do
    features
    |> Enum.find(&(&1.feature.type == "#{feature_name}"))
    |> Proto.to_map()
  end

  defp get_organization_features(org_id) do
    result =
      Wormhole.capture(__MODULE__, :get_organization_features_, [org_id],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "get_organization_features")
    end
  end

  def get_organization_features_(org_id) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.feature_client", ["get_organization_features"], fn ->
      channel
      |> FeatureService.Stub.list_organization_features(
        Util.Proto.deep_new!(%{org_id: org_id}, ListOrganizationFeaturesRequest),
        opts()
      )
    end)
  end
end
