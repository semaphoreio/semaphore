defmodule Ppl.PplSubInits.Beholder do
  @moduledoc """
  Periodically scans 'pipeline_sub_inits' table searching for
  sub_inits stuck in scheduling.

  If sub_init is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of cheduling
  - increment ppl's recovery counter

  If recovery counter is higher than 'threshold_count'
  pipeline will transition to `done`.
  """



  @period_sec Application.compile_env!(:ppl, :beholder_sub_init_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_sub_init_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_sub_init_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.PplSubInits.Model.PplSubInits,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "PipelineInitializations.state"

end
