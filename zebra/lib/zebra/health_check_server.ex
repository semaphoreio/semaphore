defmodule Zebra.Grpc.HealthCheck do
  @moduledoc """
  Serves as a backend for the gRPC health probe client used for liveness probing on Kubernetes.
  """

  require Logger

  alias Zebra.Workers
  alias Grpc.Health.V1
  alias V1.Health.Service, as: HealthService
  alias V1.HealthCheckResponse
  alias HealthCheckResponse.ServingStatus

  use GRPC.Server, service: HealthService

  def check(_request, _) do
    required_workers = Workers.active()

    if Enum.empty?(required_workers) do
      Logger.info("No required workers => OK")
      HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
    else
      check_workers(required_workers)
    end
  end

  defp check_workers(required_workers) do
    children =
      Zebra.Supervisor
      |> Supervisor.which_children()
      |> Enum.reduce([], fn {id, child, _type, _modules}, acc ->
        if is_pid(child), do: acc ++ [{id, child}], else: acc
      end)

    if Enum.all?(required_workers, fn w -> running?(children, w) end) do
      Logger.info("All required workers are running: #{inspect(required_workers)} => OK")
      HealthCheckResponse.new(status: ServingStatus.value(:SERVING))
    else
      not_running = Enum.filter(required_workers, fn w -> !running?(children, w) end)
      Logger.error("Some required workers are not running: #{inspect(not_running)} => NOT OK")
      HealthCheckResponse.new(status: ServingStatus.value(:NOT_SERVING))
    end
  end

  defp running?(children, worker) do
    case Enum.find(children, fn {name, _pid} -> name == worker end) do
      {_name, pid} -> Process.alive?(pid)
      nil -> false
    end
  end
end
