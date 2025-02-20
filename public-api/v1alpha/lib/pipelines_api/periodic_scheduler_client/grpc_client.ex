defmodule PipelinesAPI.PeriodicSchedulerClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to PeriodicScheduler service.
  """

  alias PipelinesAPI.Util.Metrics
  alias InternalApi.PeriodicScheduler.PeriodicService
  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp

  defp url(), do: System.get_env("PERIODIC_SCHEDULER_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :wormhole_timeout, [])
  @grpc_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  defp opts(), do: [{:timeout, @grpc_timeout}]

  # Apply

  def apply({:ok, apply_request}) do
    result =
      Wormhole.capture(__MODULE__, :apply_, [apply_request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "apply")
    end
  end

  def apply(error), do: error

  def apply_(apply_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client.grpc_client", ["apply"], fn ->
      channel
      |> PeriodicService.Stub.apply(apply_request, opts())
      |> Resp.ok?("apply")
    end)
  end

  # Get project id

  def get_project_id({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :get_project_id_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "get_project_id")
    end
  end

  def get_project_id(error), do: error

  def get_project_id_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.periodic_scheduler_client.grpc_client",
      ["get_project_id"],
      fn ->
        channel
        |> PeriodicService.Stub.get_project_id(request, opts())
        |> Resp.ok?("get_project_id")
      end
    )
  end

  # Describe

  def describe({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client.grpc_client", ["describe"], fn ->
      channel
      |> PeriodicService.Stub.describe(request, opts())
      |> Resp.ok?("describe")
    end)
  end

  # Delete

  def delete({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :delete_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "delete")
    end
  end

  def delete(error), do: error

  def delete_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client.grpc_client", ["delete"], fn ->
      channel
      |> PeriodicService.Stub.delete(request, opts())
      |> Resp.ok?("delete")
    end)
  end

  # List

  def list({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client.grpc_client", ["list"], fn ->
      channel
      |> PeriodicService.Stub.list(request, opts())
      |> Resp.ok?("list")
    end)
  end

  # Run now

  def run_now({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :run_now_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "run_now")
    end
  end

  def run_now(error), do: error

  def run_now_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.periodic_scheduler_client.grpc_client", ["run_now"], fn ->
      channel
      |> PeriodicService.Stub.run_now(request, opts())
      |> Resp.ok?("run_now")
    end)
  end
end
