defmodule Gofer.Grpc.HealthCheck do
  @moduledoc """
  Serves as an backend for a go client used for livness probing on kubernetes.
  """

  alias Grpc.Health.V1
  alias V1.Health.Service, as: HealthService
  alias V1.HealthCheckResponse
  alias HealthCheckResponse.ServingStatus
  alias InternalApi.Gofer.{VersionRequest, Switch}

  use GRPC.Server, service: HealthService

  def check(_request, _) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    request = VersionRequest.new()

    {:ok, _response} = Switch.Stub.version(channel, request)

    HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
  end
end
