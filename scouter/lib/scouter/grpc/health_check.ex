defmodule Scouter.GRPC.HealthCheck do
  use GRPC.Server, service: Grpc.Health.V1.Health.Service

  alias Grpc.Health.V1.HealthCheckResponse

  def check(_req, _stream) do
    %HealthCheckResponse{status: HealthCheckResponse.ServingStatus.value(:SERVING)}
  end
end
