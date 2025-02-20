defmodule GithubNotifier.Models.PipelineSummary do
  require Logger

  defstruct [
    :pipeline_id,
    :total,
    :passed,
    :skipped,
    :error,
    :failed,
    :disabled,
    :duration
  ]

  alias GithubNotifier.Models.PipelineSummary

  alias InternalApi.Velocity.{
    ListPipelineSummariesRequest,
    ListPipelineSummariesResponse,
    PipelineMetricsService.Stub
  }

  @type t :: %PipelineSummary{}
  @type uuid :: String.t()

  @spec find(uuid()) :: {:ok, PipelineSummary.t()} | {:error, String.t()}
  def find(pipeline_id) do
    Watchman.benchmark("fetch_pipeline_summary.duration", fn ->
      request = %ListPipelineSummariesRequest{pipeline_ids: [pipeline_id]}

      channel()
      |> case do
        {:ok, channel} ->
          Stub.list_pipeline_summaries(channel, request)

        error ->
          error
      end
      |> case do
        {:ok, %ListPipelineSummariesResponse{pipeline_summaries: [pipeline_summary]}} ->
          construct(pipeline_summary)

        {:ok, _} ->
          Logger.warn("Pipeline summary not found for a pipeline: #{pipeline_id}")
          nil

        error ->
          log_error(error)

          nil
      end
    end)
  end

  defp construct(pipeline_summary) do
    %{
      pipeline_id: pipeline_summary.pipeline_id,
      total: pipeline_summary.summary.total,
      passed: pipeline_summary.summary.passed,
      skipped: pipeline_summary.summary.skipped,
      error: pipeline_summary.summary.error,
      failed: pipeline_summary.summary.failed,
      disabled: pipeline_summary.summary.disabled,
      duration: pipeline_summary.summary.duration
    }
  end

  def is_failed?(pipeline_summary) do
    pipeline_summary.failed + pipeline_summary.error > 0
  end

  def is_passed?(pipeline_summary) do
    !is_failed?(pipeline_summary) &&
      pipeline_summary.passed > 0 &&
      pipeline_summary.total > 0
  end

  defp channel do
    Application.fetch_env!(:github_notifier, :velocityhub_api_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp log_error({:error, error}) do
    error
    |> inspect
    |> Logger.error()
  end

  defp log_error(other) do
    """
    Unexpected response:
    #{inspect(other)}
    """
    |> Logger.error()
  end
end
