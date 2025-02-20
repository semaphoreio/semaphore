defmodule Front.Models.ProjectMetrics.PipelineFrequency do
  alias InternalApi.Velocity.{
    FrequencyMetric,
    ListPipelineFrequencyMetricsResponse
  }

  alias __MODULE__

  defstruct metrics: []

  @type metric :: %{
          from_date: DateTime.t(),
          to_date: DateTime.t(),
          count: integer
        }

  @type t :: %__MODULE__{
          metrics: [metric()]
        }

  @spec from_proto(proto :: ListPipelineFrequencyMetricsResponse.t()) :: t
  def from_proto(response = %ListPipelineFrequencyMetricsResponse{}) do
    %PipelineFrequency{
      metrics:
        Enum.map(response.metrics, &process_metric/1)
        |> Enum.sort(&(Date.compare(&1.from_date, &2.from_date) != :lt))
    }
  end

  @spec process_metric(FrequencyMetric.t()) :: metric()
  defp process_metric(metric = %FrequencyMetric{}) do
    %{
      from_date: Timex.from_unix(metric.from_date.seconds),
      to_date: Timex.from_unix(metric.to_date.seconds),
      count: metric.all_count
    }
  end
end
