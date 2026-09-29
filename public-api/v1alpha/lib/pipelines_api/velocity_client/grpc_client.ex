defmodule PipelinesAPI.VelocityClient.GrpcClient do
  @moduledoc "gRPC calls to the Velocity PipelineMetricsService."

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp
  alias InternalApi.Velocity.PipelineMetricsService.Stub

  defp url(), do: System.get_env("INTERNAL_API_URL_VELOCITY")
  defp opts(), do: [{:timeout, timeout()}]
  defp timeout(), do: Application.get_env(:pipelines_api, :grpc_timeout)

  def list_pipeline_performance_metrics({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_pipeline_performance_metrics_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_pipeline_performance_metrics")
    end
  end

  def list_pipeline_performance_metrics(error), do: error

  def list_pipeline_performance_metrics_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.velocity_client.grpc_client",
      ["list_pipeline_performance_metrics"],
      fn ->
        channel
        |> Stub.list_pipeline_performance_metrics(request, opts())
        |> Resp.ok?("list_pipeline_performance_metrics")
      end
    )
  end

  def list_pipeline_reliability_metrics({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_pipeline_reliability_metrics_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_pipeline_reliability_metrics")
    end
  end

  def list_pipeline_reliability_metrics(error), do: error

  def list_pipeline_reliability_metrics_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.velocity_client.grpc_client",
      ["list_pipeline_reliability_metrics"],
      fn ->
        channel
        |> Stub.list_pipeline_reliability_metrics(request, opts())
        |> Resp.ok?("list_pipeline_reliability_metrics")
      end
    )
  end

  def list_pipeline_frequency_metrics({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_pipeline_frequency_metrics_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_pipeline_frequency_metrics")
    end
  end

  def list_pipeline_frequency_metrics(error), do: error

  def list_pipeline_frequency_metrics_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.velocity_client.grpc_client",
      ["list_pipeline_frequency_metrics"],
      fn ->
        channel
        |> Stub.list_pipeline_frequency_metrics(request, opts())
        |> Resp.ok?("list_pipeline_frequency_metrics")
      end
    )
  end
end
