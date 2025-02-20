defmodule RepositoryHub.Server.HealthCheck do
  use GRPC.Server, service: Grpc.Health.V1.Health.Service

  alias Grpc.Health.V1.HealthCheckResponse

  def check(_req, _stream) do
    %HealthCheckResponse{
      status: :SERVING
    }
  end
end
