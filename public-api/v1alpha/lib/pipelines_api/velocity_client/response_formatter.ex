defmodule PipelinesAPI.VelocityClient.ResponseFormatter do
  @moduledoc "Reshapes Velocity insights protobuf responses into JSON-friendly maps."

  @perf_fields ~w(count mean_seconds median_seconds min_seconds max_seconds std_dev_seconds p95_seconds)a
  @reliab_fields ~w(all_count passed_count failed_count)a
  @freq_fields ~w(all_count)a

  @spec process_performance_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, any()}
  def process_performance_response({:ok, resp}) when is_map(resp) do
    {:ok,
     %{
       all: Enum.map(resp.all_metrics || [], &perf_metric/1),
       passed: Enum.map(resp.passed_metrics || [], &perf_metric/1),
       failed: Enum.map(resp.failed_metrics || [], &perf_metric/1)
     }}
  end

  def process_performance_response(error), do: error

  @spec process_reliability_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, any()}
  def process_reliability_response({:ok, resp}) when is_map(resp),
    do: {:ok, %{metrics: Enum.map(resp.metrics || [], &metric(&1, @reliab_fields))}}

  def process_reliability_response(error), do: error

  @spec process_frequency_response({:ok, map()} | {:error, any()}) ::
          {:ok, map()} | {:error, any()}
  def process_frequency_response({:ok, resp}) when is_map(resp),
    do: {:ok, %{metrics: Enum.map(resp.metrics || [], &metric(&1, @freq_fields))}}

  def process_frequency_response(error), do: error

  defp perf_metric(m), do: metric(m, @perf_fields)

  defp metric(m, fields) do
    m
    |> Map.take(fields)
    |> Map.put(:from_date, ts(Map.get(m, :from_date)))
    |> Map.put(:to_date, ts(Map.get(m, :to_date)))
  end

  defp ts(nil), do: nil

  defp ts(%{seconds: s}) when is_integer(s) and s > 0 do
    case DateTime.from_unix(s) do
      {:ok, dt} -> DateTime.to_string(dt)
      _ -> nil
    end
  end

  defp ts(_), do: nil
end
