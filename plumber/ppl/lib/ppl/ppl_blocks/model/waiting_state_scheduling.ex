defmodule Ppl.PplBlocks.Model.WaitingStateScheduling do
  @moduledoc """
  Find ready ppl_block - ppl_block ready for scheduling.

  Two groups compete: blocks with a terminate request and ready blocks.
  `get_ready_block(:terminate_first)` claims from the terminate group and
  falls back to ready blocks; `:ready_first` does the opposite. The STM
  alternates the two within a batch, so stops are not delayed behind a
  scheduling backlog and a burst of stops cannot starve ready blocks.
  Within each group the least recently updated block is claimed first.
  A ready block that also has a terminate request can be claimed from the
  ready group; the STM runs the terminate handler for it either way.
  """

  alias Ppl.Query2Ecto.STM
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.EctoRepo, as: Repo
  alias Util.Metrics

  def get_ready_block(order \\ :terminate_first) do
    Metrics.benchmark("Ppl.ppl_blk.waiting_STM", "enter_scheduling",  fn ->
      with {:ok, resp} <- Repo.transaction(fn -> do_get_ready_block(order) end),
        do: resp
    end)
  end

  def do_get_ready_block(order \\ :terminate_first)

  def do_get_ready_block(:terminate_first),
    do: claim_first_of([&claim_terminate_requested/0, &claim_ready/0])

  def do_get_ready_block(:ready_first),
    do: claim_first_of([&claim_ready/0, &claim_terminate_requested/0])

  defp claim_first_of([claim_fun | rest]) do
    case claim_fun.() do
      {:ok, []} when rest != [] -> claim_first_of(rest)
      resp -> resp
    end
  end

  defp claim_terminate_requested, do: claim(terminate_requested_ppl_block_query())

  defp claim_ready do
    not_ready_ppl_blocks_query()
    |> ready_ppl_block_query()
    |> claim()
  end

  defp claim(select_query) do
    select_query
    |> ready_ppl_block_update_query()
    |> Repo.query([NaiveDateTime.utc_now()])
    |> STM.load(PplBlocks)
  end

  def ready_ppl_block_update_query(select_query) do "
    UPDATE pipeline_blocks AS ppl_blk
    SET in_scheduling = true, updated_at = $1
    FROM (#{select_query}) AS subquery
    WHERE ppl_blk.id = subquery.id and ppl_blk.in_scheduling = false
    RETURNING ppl_blk.*, subquery.updated_at as old_update_time
  " end

  # Uses the partial index pipeline_blocks_waiting_terminate_requested_index.
  defp terminate_requested_ppl_block_query do "
    SELECT pb.*
    FROM pipeline_blocks AS pb
    WHERE pb.in_scheduling = false AND
      pb.state = 'waiting' AND
      pb.terminate_request IS NOT NULL
    ORDER BY pb.updated_at ASC
    LIMIT 1
    FOR UPDATE OF pb SKIP LOCKED
  " end

  # Walks the (in_scheduling, state, updated_at) index oldest first.
  defp ready_ppl_block_query(not_ready_ppl_blocks_query) do "
    SELECT pb.*
    FROM pipeline_blocks AS pb
    JOIN pipelines as ppl
      ON pb.ppl_id = ppl.ppl_id
    WHERE pb.in_scheduling = false AND
      pb.state = 'waiting' AND
      /* Do not consider pipelines that are stil in state transition. */
      ppl.state = 'running' AND
      NOT EXISTS (#{not_ready_ppl_blocks_query})
    ORDER BY pb.updated_at ASC
    LIMIT 1
    FOR UPDATE OF pb SKIP LOCKED
  " end

  # Get ppl_blocks that are in WAITING state but not ready to run.
  # Not ready to run == at least one of its dependencies is not in DONE state
  defp not_ready_ppl_blocks_query do "
    SELECT targets.id
    FROM pipeline_blocks AS targets
    JOIN pipeline_block_connections AS connections
      ON targets.id = connections.target
    JOIN pipeline_blocks AS dependencies
      ON connections.dependency = dependencies.id
    WHERE targets.state = 'waiting' AND
      dependencies.state NOT IN ('done') and targets.id = pb.id
  " end
end
