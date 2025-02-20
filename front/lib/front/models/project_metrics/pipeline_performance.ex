defmodule Front.Models.ProjectMetrics.PipelinePerformance do
  alias InternalApi.Velocity.{
    ListPipelinePerformanceMetricsResponse,
    PerformanceMetric
  }

  alias __MODULE__

  defstruct all: [], passed: [], failed: []

  @type metric :: %{
          from_date: DateTime.t(),
          to_date: DateTime.t(),
          count: integer,
          mean: integer,
          min: integer,
          max: integer,
          std_dev: integer,
          p50: integer,
          p95: integer
        }

  @type t :: %__MODULE__{
          all: [metric()],
          passed: [metric()],
          failed: [metric()]
        }

  @spec from_proto(proto :: ListPipelinePerformanceMetricsResponse.t()) :: t
  def from_proto(response = %ListPipelinePerformanceMetricsResponse{}) do
    %PipelinePerformance{
      all:
        Enum.map(response.all_metrics, &process_metric/1)
        |> Enum.sort(&(Date.compare(&1.from_date, &2.from_date) != :lt)),
      passed:
        Enum.map(response.passed_metrics, &process_metric/1)
        |> Enum.sort(&(Date.compare(&1.from_date, &2.from_date) != :lt)),
      failed:
        Enum.map(response.failed_metrics, &process_metric/1)
        |> Enum.sort(&(Date.compare(&1.from_date, &2.from_date) != :lt))
    }
  end

  @spec process_metric(PerformanceMetric.t()) :: metric()
  defp process_metric(metric = %PerformanceMetric{}) do
    %{
      from_date: Timex.from_unix(metric.from_date.seconds),
      to_date: Timex.from_unix(metric.to_date.seconds),
      count: metric.count,
      mean: metric.mean_seconds,
      min: metric.min_seconds,
      max: metric.max_seconds,
      std_dev: metric.std_dev_seconds,
      p50: metric.median_seconds,
      p95: metric.p95_seconds
    }
  end
end
