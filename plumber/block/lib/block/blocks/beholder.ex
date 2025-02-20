defmodule Block.Blocks.Beholder do
  @moduledoc """
  Periodically scans 'blocks' table searching for blocks stuck in scheduling.

  All scheduling activities have to be finished within Wormhole timeout
  (by default 5 seconds).
  After that block is stuck.
  """

  @period_sec Application.compile_env!(:block, :beholder_blk_sleep_period_sec)
  @threshold_sec Application.compile_env!(:block, :beholder_blk_threshold_sec)
  @threshold_count Application.compile_env!(:block, :beholder_blk_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Block.Blocks.Model.Blocks,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Block.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count
end
