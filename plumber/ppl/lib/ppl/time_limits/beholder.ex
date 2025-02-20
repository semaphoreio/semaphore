defmodule Ppl.TimeLimits.Beholder do
  @moduledoc """
  Periodically scans 'time_limits' table searching for
  time_limit stuck in scheduling.

  If time_limit is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of cheduling
  - increment ppl's recovery counter

  If recovery counter is higher than 'threshold_count'
  time_limit will transition to `done`.
  """


  @period_sec Application.compile_env!(:ppl, :beholder_time_limits_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_time_limits_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_time_limits_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.TimeLimits.Model.TimeLimits,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "canceled",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count

end
