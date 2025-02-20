defmodule Front.Models.TestSummary do
  require Logger
  use TypedStruct
  alias __MODULE__

  alias InternalApi.Velocity.{
    JobSummary,
    PipelineSummary
  }

  @type parsable_types :: PipelineSummary.t() | JobSummary.t() | t() | nil

  typedstruct do
    field(:total, integer(), default: 0)
    field(:passed, integer(), default: 0)
    field(:skipped, integer(), default: 0)
    field(:error, integer(), default: 0)
    field(:failed, integer(), default: 0)
    field(:disabled, integer(), default: 0)
    field(:duration, integer(), default: 0)
  end

  defguard is_failed?(test_summary)
           when test_summary.failed + test_summary.error > 0

  defguard is_empty?(test_summary)
           when test_summary.total <= 0 or test_summary.total == nil

  defguard is_passed?(test_summary)
           when (test_summary.passed > 0 or test_summary.disabled > 0 or test_summary.skipped > 0) and
                  not is_failed?(test_summary) and
                  not is_empty?(test_summary)

  @spec total(t) :: integer()
  def total(test_summary) do
    test_summary.total
  end

  @spec passed(t) :: integer()
  def passed(test_summary) do
    test_summary.passed
  end

  @spec skipped(t) :: integer()
  def skipped(test_summary) do
    test_summary.skipped + test_summary.disabled
  end

  @spec failed(t) :: integer()
  def failed(test_summary) do
    test_summary.failed + test_summary.error
  end

  @spec load(parsable_types()) :: t()
  def load(%JobSummary{summary: summary}) do
    %TestSummary{
      total: fetch_with_default(summary, :total),
      passed: fetch_with_default(summary, :passed),
      skipped: fetch_with_default(summary, :skipped),
      error: fetch_with_default(summary, :error),
      failed: fetch_with_default(summary, :failed),
      disabled: fetch_with_default(summary, :disabled),
      duration: fetch_with_default(summary, :duration)
    }
  end

  def load(%PipelineSummary{summary: summary}) do
    %TestSummary{
      total: fetch_with_default(summary, :total),
      passed: fetch_with_default(summary, :passed),
      skipped: fetch_with_default(summary, :skipped),
      error: fetch_with_default(summary, :error),
      failed: fetch_with_default(summary, :failed),
      disabled: fetch_with_default(summary, :disabled),
      duration: fetch_with_default(summary, :duration)
    }
  end

  def load(test_summary = %TestSummary{}), do: test_summary
  def load(nil), do: nil

  defp fetch_with_default(_, _, default \\ 0)

  defp fetch_with_default(struct, field, default) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> fetch_with_default(field, default)
  end

  defp fetch_with_default(map, field, default) when is_map(map) do
    map
    |> Map.get(field, default)
  end

  defp fetch_with_default(_, _, default) do
    default
  end
end
