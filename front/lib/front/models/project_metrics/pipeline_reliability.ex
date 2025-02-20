defmodule Front.Models.ProjectMetrics.PipelineReliability do
  alias InternalApi.Velocity.{
    ListPipelineReliabilityMetricsResponse,
    ReliabilityMetric
  }

  alias __MODULE__

  defstruct metrics: []

  @type t :: %__MODULE__{
          metrics: [ReliabilityMetric.t()]
        }

  @type metric :: %{
          from_date: DateTime.t(),
          to_date: DateTime.t(),
          all_count: integer,
          passed_count: integer,
          failed_count: integer
        }

  @spec from_proto(proto :: ListPipelineReliabilityMetricsResponse.t()) :: t
  def from_proto(response = %ListPipelineReliabilityMetricsResponse{}) do
    %PipelineReliability{
      metrics:
        Enum.map(response.metrics, &process_metric/1)
        |> Enum.sort(&(Date.compare(&1.from_date, &2.from_date) != :lt))
    }
  end

  @spec process_metric(ReliabilityMetric.t()) :: metric()
  defp process_metric(metric = %ReliabilityMetric{}) do
    %{
      from_date: Timex.from_unix(metric.from_date.seconds),
      to_date: Timex.from_unix(metric.to_date.seconds),
      all_count: metric.all_count,
      passed_count: metric.passed_count,
      failed_count: metric.failed_count
    }
  end
end
