defmodule TaskApiReferent.Grpc.HealthCheck do
  @moduledoc """
  Serves as an backend for a go client used for liveness probing on kubernetes.
  """

  alias Grpc.Health.V1
  alias V1.Health.Service, as: HealthService
  alias V1.HealthCheckResponse
  alias HealthCheckResponse.ServingStatus
  alias InternalApi.Task.{DescribeRequest, TaskService}

  use GRPC.Server, service: HealthService

  def check(_request, _) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = DescribeRequest.new(task_id: "00000000-abcd-bcde-cdef-000000000000")
    status = GRPC.Status.not_found

    {:error, %GRPC.RPCError{status: ^status}} =
      channel
      |> TaskService.Stub.describe(request)

    HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
  end
end
