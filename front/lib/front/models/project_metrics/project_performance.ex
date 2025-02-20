defmodule Front.Models.ProjectMetrics.ProjectPerformance do
  alias InternalApi.Velocity.DescribeProjectPerformanceResponse

  alias __MODULE__

  defstruct mean_time_to_recovery: nil, last_successful_run_at: nil

  @type t :: %__MODULE__{
          mean_time_to_recovery: integer,
          last_successful_run_at: DateTime.t()
        }

  @spec from_proto(proto :: DescribeProjectPerformanceResponse.t()) :: t()
  def from_proto(response = %DescribeProjectPerformanceResponse{}) do
    %ProjectPerformance{
      mean_time_to_recovery: response.mean_time_to_recovery_seconds,
      last_successful_run_at: Timex.from_unix(response.last_successful_run_at.seconds)
    }
  end
end
