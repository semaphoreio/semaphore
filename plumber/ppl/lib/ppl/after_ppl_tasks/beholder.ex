defmodule Ppl.AfterPplTasks.Beholder do
  @moduledoc """
  Periodically scans 'after_tasks' table searching for
  after_tasks stuck in scheduling.

  If after_task is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of scheduling
  - increment ppl's recovery counter

  If recovery counter is higher than 'threshold_count'
  pipeline will transition to `done`.
  """

  alias Ppl.AfterPplTasks.Model.AfterPplTasks

  @period_sec Application.compile_env!(:ppl, :beholder_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: AfterPplTasks,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "AfterPipelines.state"
end
