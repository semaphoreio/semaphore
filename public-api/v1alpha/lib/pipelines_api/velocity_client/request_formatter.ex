defmodule PipelinesAPI.VelocityClient.RequestFormatter do
  @moduledoc "Builds Velocity insights protobuf requests from HTTP params."

  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Velocity.{
    ListPipelinePerformanceMetricsRequest,
    ListPipelineReliabilityMetricsRequest,
    ListPipelineFrequencyMetricsRequest
  }

  alias Google.Protobuf.Timestamp

  @spec form_performance_request(map()) ::
          {:ok, ListPipelinePerformanceMetricsRequest.t()} | {:error, any()}
  def form_performance_request(params), do: build(ListPipelinePerformanceMetricsRequest, params)

  @spec form_reliability_request(map()) ::
          {:ok, ListPipelineReliabilityMetricsRequest.t()} | {:error, any()}
  def form_reliability_request(params), do: build(ListPipelineReliabilityMetricsRequest, params)

  @spec form_frequency_request(map()) ::
          {:ok, ListPipelineFrequencyMetricsRequest.t()} | {:error, any()}
  def form_frequency_request(params), do: build(ListPipelineFrequencyMetricsRequest, params)

  defp build(mod, params) when is_map(params) do
    with {:ok, pipeline_file} <- required(params, "pipeline_file") do
      struct(mod, %{
        project_id: params["project_id"] || "",
        pipeline_file_name: pipeline_file,
        branch_name: params["branch"] || "",
        aggregate: aggregate(params["aggregate"]),
        from_date: to_ts(params["from"]),
        to_date: to_ts(params["to"])
      })
      |> ToTuple.ok()
    end
  end

  defp build(_mod, _), do: ToTuple.internal_error("Internal error")

  defp required(params, key) do
    case Map.get(params, key) do
      v when is_binary(v) and v != "" -> {:ok, v}
      _ -> ToTuple.user_error("Missing required query parameter: #{key}")
    end
  end

  # MetricAggregation: RANGE=0, DAILY=1; default DAILY
  defp aggregate("range"), do: 0
  defp aggregate(_), do: 1

  defp to_ts(nil), do: nil

  defp to_ts(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        {:ok, dt} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
        %Timestamp{seconds: DateTime.to_unix(dt), nanos: 0}

      _ ->
        nil
    end
  end
end
