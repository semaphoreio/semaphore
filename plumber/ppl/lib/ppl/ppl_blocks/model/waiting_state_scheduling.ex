defmodule Ppl.PplBlocks.Model.WaitingStateScheduling do
  @moduledoc """
  Find ready ppl_block - ppl_block ready for scheduling.
  """

  alias Ppl.Query2Ecto.STM
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.EctoRepo, as: Repo
  alias Util.Metrics

  def get_ready_block do
    Metrics.benchmark("Ppl.ppl_blk.waiting_STM", "enter_scheduling",  fn ->
      with {:ok, resp} <- Repo.transaction(&do_get_ready_block/0),
        do: resp
    end)
  end

  def do_get_ready_block do
    not_ready_ppl_blocks_query()
    |> ready_ppl_block_query()
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

  defp ready_ppl_block_query(not_ready_ppl_blocks_query) do "
    SELECT pb.*
    FROM pipeline_blocks AS pb
    JOIN pipelines as ppl
      ON pb.ppl_id = ppl.ppl_id
    WHERE pb.in_scheduling = false AND
      pb.state = 'waiting' AND (
        (
        /* Do not consider pipelines that are stil in state transition. */
        ppl.state = 'running' AND
        NOT EXISTS (#{not_ready_ppl_blocks_query})
        )
      OR
        pb.terminate_request IS NOT NULL
      )
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
