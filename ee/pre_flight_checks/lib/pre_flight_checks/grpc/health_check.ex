defmodule PreFlightChecks.GRPC.HealthCheck do
  @moduledoc """
  Serves as an backend for a go client used for liveness probing on kubernetes.
  """

  alias Grpc.Health.V1.Health.Service, as: HealthService
  alias Grpc.Health.V1.{HealthCheckResponse, HealthCheckResponse.ServingStatus}
  alias InternalApi.PreFlightChecksHub, as: API
  alias API.PreFlightChecksService, as: APIService

  use GRPC.Server, service: HealthService

  def check(_request, _) do
    request = API.DescribeRequest.new()

    with {:ok, channel} <- GRPC.Stub.connect("localhost:50051"),
         {:ok, _response} <- grpc_send(channel, request) do
      HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
    end
  end

  defp grpc_send(channel, request),
    do: APIService.Stub.describe(channel, request),
    after: GRPC.Stub.disconnect(channel)
end
