defmodule Ppl.Grpc.HealthCheck do
  @moduledoc """
  Serves as an backend for a go client used for liveness probing on kubernetes.
  """

  alias Grpc.Health.V1
  alias V1.Health.Service, as: HealthService
  alias V1.HealthCheckResponse
  alias HealthCheckResponse.ServingStatus
  alias InternalApi.Plumber.{VersionRequest, PipelineService}

  use GRPC.Server, service: HealthService

  def check(_request, _) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    request = VersionRequest.new()

    {:ok, _response} =
      PipelineService.Stub.version(channel, request)

    HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
  end
end
