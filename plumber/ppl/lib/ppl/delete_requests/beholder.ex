defmodule Ppl.DeleteRequests.Beholder do
  @moduledoc """
  Periodically scans 'delete_requests' table searching for
  delete_requests stuck in scheduling.

  If delete_request is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of scheduling
  - increment it's recovery counter

  If recovery counter is higher than 'threshold_count'
  delete_request will transition to `done`.
  """



  @period_sec Application.compile_env!(:ppl, :beholder_dr_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_dr_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_dr_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.DeleteRequests.Model.DeleteRequests,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count

end
