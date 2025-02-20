defmodule Ppl.PplBlocks.Beholder do
  @moduledoc """
  Periodically scans 'pipeline blocks' table searching for
  pipeline blocks stuck in scheduling.

  All scheduling activities have to be finished within Wormhole timeout
  (by default 5 seconds).
  After that pipeline's block is stuck.
  """

  alias Ppl.PplBlocks.STMHandler.Common
  alias Looper.STM.Publisher

  @period_sec Application.compile_env!(:ppl, :beholder_ppl_blk_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_ppl_blk_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_ppl_blk_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.PplBlocks.Model.PplBlocks,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "Blocks.state",
    callback: fn ppl_blk -> apply(__MODULE__, :post_proccessing, [ppl_blk]) end

    def post_proccessing(ppl_blk) do
      Publisher.publish(Map.take(ppl_blk, [:ppl_id, :block_id]),
                        "done",
                        fn params -> Common.publisher_callback(params) end)
    end
end
