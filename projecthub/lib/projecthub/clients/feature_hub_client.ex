defmodule Projecthub.FeatureHubClient do
  @moduledoc """
  Client for communication with the Feature service.
  """

  alias Projecthub.Util.GRPC.{
    ClientMetricsInterceptor,
    ClientRequestIdInterceptor,
    ClientLoggerInterceptor,
    ClientRunAsyncInterceptor
  }

  use Projecthub.GrpcClient,
    service: InternalApi.Feature.FeatureService,
    endpoint: Application.fetch_env!(:projecthub, :feature_grpc_endpoint),
    interceptors: [
      {ClientMetricsInterceptor, "feature_hub"},
      ClientRequestIdInterceptor,
      ClientLoggerInterceptor,
      ClientRunAsyncInterceptor
    ]

  alias InternalApi.Feature.{
    ListOrganizationFeaturesRequest,
    ListOrganizationFeaturesResponse,
    ListFeaturesRequest,
    ListFeaturesResponse
  }

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec list_organization_features(rpc_request(ListOrganizationFeaturesRequest.t())) ::
          rpc_response(ListOrganizationFeaturesResponse.t())
  def list_organization_features(request),
    do:
      request
      |> decorate(ListOrganizationFeaturesRequest)
      |> grpc_call(:list_organization_features)

  @spec list_features(rpc_request(ListFeaturesRequest.t())) ::  rpc_response(ListFeaturesResponse.t())
  def list_features(request),
    do:
      request
      |> decorate(ListFeaturesRequest)
      |> grpc_call(:list_features)
end
