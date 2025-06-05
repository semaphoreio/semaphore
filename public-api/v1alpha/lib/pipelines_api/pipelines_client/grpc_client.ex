defmodule PipelinesAPI.PipelinesClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Pipelines service.
  """

  alias PipelinesAPI.Util.Metrics
  alias InternalApi.Plumber.PipelineService
  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp

  defp url(), do: System.get_env("PPL_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  defp timeout(), do: Application.get_env(:pipelines_api, :grpc_timeout)

  # Describe

  def describe({:ok, describe_request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_, [describe_request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["describe"], fn ->
      channel
      |> PipelineService.Stub.describe(describe_request, opts())
      |> Resp.ok?("describe")
    end)
  end

  # Terminate

  def terminate({:ok, terminate_request}) do
    result =
      Wormhole.capture(__MODULE__, :terminate_, [terminate_request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "terminate")
    end
  end

  def terminate(error), do: error

  def terminate_(terminate_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["terminate"], fn ->
      channel
      |> PipelineService.Stub.terminate(terminate_request, opts())
      |> Resp.ok?("terminate")
    end)
  end

  # List

  def list({:ok, list_request}) do
    result =
      Wormhole.capture(__MODULE__, :list_, [list_request], timeout: timeout(), stacktrace: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(list_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["list"], fn ->
      channel
      |> PipelineService.Stub.list(list_request, opts())
      |> Resp.ok?("list")
    end)
  end

  # GetProjectId

  def get_project_id({:ok, get_project_id_request}) do
    result =
      Wormhole.capture(
        __MODULE__,
        :get_project_id_,
        [get_project_id_request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "get_project_id")
    end
  end

  def get_project_id(error), do: error

  def get_project_id_(get_project_id_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["get_project_id"], fn ->
      channel
      |> PipelineService.Stub.get_project_id(get_project_id_request, opts())
      |> Resp.ok?("get_project_id")
    end)
  end

  # DescribeTopology

  def describe_topology({:ok, describe_topology_request}) do
    result =
      Wormhole.capture(
        __MODULE__,
        :describe_topology_,
        [describe_topology_request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe_topology")
    end
  end

  def describe_topology(error), do: error

  def describe_topology_(describe_topology_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["describe_topology"], fn ->
      channel
      |> PipelineService.Stub.describe_topology(describe_topology_request, opts())
      |> Resp.ok?("describe_topology")
    end)
  end

  # PartialRebuild

  def partial_rebuild({:ok, partial_rebuild_request}) do
    Wormhole.capture(__MODULE__, :partial_rebuild_, [partial_rebuild_request],
      timeout: timeout(),
      stacktrace: true
    )
    |> case do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "partial_rebuild")
    end
  end

  def partial_rebuild(error), do: error

  def partial_rebuild_(partial_rebuild_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["partial_rebuild"], fn ->
      channel
      |> PipelineService.Stub.partial_rebuild(partial_rebuild_request, opts())
      |> Resp.ok?("partial_rebuild")
    end)
  end

  # Validate YAML

  def validate_yaml({:ok, validate_request}) do
    result =
      Wormhole.capture(__MODULE__, :validate_yaml_, [validate_request],
        timeout: timeout(),
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "validate_yaml")
    end
  end

  def validate_yaml(error), do: error

  def validate_yaml_(validate_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.ppl_client.grpc_client", ["validate_yaml"], fn ->
      channel
      |> PipelineService.Stub.validate_yaml(validate_request, opts())
      |> Resp.ok?("validate_yaml")
    end)
  end

  # Version

  def version(version_request) do
    result = Wormhole.capture(__MODULE__, :version_, [version_request], stacktrace: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "version")
    end
  end

  def version_(version_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> PipelineService.Stub.version(version_request, opts())
    |> Resp.ok?("version")
  end
end
