defmodule Ppl.Ppls.Beholder do
  @moduledoc """
  Periodically scans 'pipelines' table searching for
  pipelines stuck in scheduling.

  If pipeline is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of cheduling
  - increment ppl's recovery counter

  If recovery counter is higher than 'threshold_count'
  pipeline will transition to `done`.
  """

  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.STMHandler.Common
  alias Looper.STM.Publisher
  alias Ppl.PplBlocks.Model.PplBlocksQueries

  @period_sec Application.compile_env!(:ppl, :beholder_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.Ppls.Model.Ppls,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "Pipelines.state",
    callback: fn ppl -> apply(__MODULE__, :post_proccessing, [ppl]) end

  def post_proccessing(ppl) do
    set_done_at_timestamp(ppl)

    terminate_ppl_blks(ppl)

    Publisher.publish(Map.take(ppl, [:ppl_id]),
                      "done",
                      fn params -> Common.publisher_callback(params) end)
  end

  def set_done_at_timestamp(ppl) do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
  end

  def terminate_ppl_blks(ppl) do
    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl.ppl_id)

    blocks
    |> Enum.each(fn block ->
      block |> PplBlocksQueries.terminate("cancel", "Pipeline terminated")
    end)
  end
end
