defmodule Block.Blocks.Model.BlocksQueries do
  @moduledoc """
  Block Queries
  Operations on Block type

  'initializing' - initial block state.
  Waiting for cmd_file -> commands replacement and creation of task event
  and block subppl events.
  From 'initializing' block transitions to 'running' or 'done'.

  'running'
  Either block's task or one or more of it's subpipelines are still in progress.
  The block will be fetched by some looper later and checked again.
  From 'running' block transitions to 'stopping' or 'done'.

  'stopping'
  Block's execution termination is initialized, waiting for task and all subpipelines
  to terminate.
  From 'stopping' block transitions to 'done'.

  'done' - terminal state
  Block execution is done and execution status is saved in 'result' field.
  """

  require Block.Ctx

  import Ecto.Query

  alias Block.EctoRepo, as: Repo
  alias Block.Ctx
  alias Block.Blocks.Model.Blocks
  alias Block.Tasks.Model.Tasks
  alias Block.BlockRequests.Model.BlockRequests
  alias Util.ToTuple

  def insert(ctx) do
    event = %{block_id: ctx.id}
      |> Map.put(:state, "initializing")
      |> Map.put(:in_scheduling, "false")

    try do
      %Blocks{} |> Blocks.changeset(event) |> Repo.insert
      |> Ctx.event("initializing")
    rescue
      e ->  rescue_(e, ctx.id)
    end
  end

  defp rescue_(%Ecto.ConstraintError{constraint: "blocks_block_id_index"}, block_id) do
    get_by_id(block_id)
  end
  defp rescue_(e, _), do: {:error, e}


  @doc """
  Duplicates passed Blocks and changes block_id to new value.
  Used in partial rebuilding to avoid reruning passed blocks.
  """
  def duplicate(block_id, new_block_id) do
    block_id |> get_by_id() |> change_ids(new_block_id) |> duplicate()
  end

  defp change_ids({:ok, blk = %{state: "done", result: "passed"}}, new_block_id) do
    blk
    |> Map.from_struct()
    |> Map.drop([:id, :block_id])
    |> Map.put(:block_id, new_block_id)
    |> ToTuple.ok()
  end
  defp change_ids({:ok, %{block_id: id}}, _new_block_id),
    do: "Can not dupplicate block #{id} because it's result is not 'passed'." |> ToTuple.error()
  defp change_ids(error, _new_block_id), do: error

  defp duplicate({:ok, params}) do
    try do
      %Blocks{} |> Blocks.changeset(params) |> Repo.insert()
    rescue
      e ->  case e do
              %Ecto.ConstraintError{constraint: "blocks_block_id_index"} ->
                get_by_id(params.block_id)
              error -> {:error, error}
            end
    end
  end
  defp duplicate(error), do: error

  @doc """
  Returns details for all blocks from pipeline with given ppl_id
  """
  def list(ppl_id) do
    (from b in Blocks,
     join: br in BlockRequests, on: b.block_id == br.id,
     left_join: t in Tasks, on: b.block_id == t.block_id)
    |> where([_b, br], br.ppl_id == ^ppl_id)
    |> list_select_query()
    |> order_by([_b, br], asc: br.pple_block_index)
    |> Repo.all([])
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp list_select_query(query) do
    query
    |> select([b, _br, t],
      %{
        block_id: b.block_id,
        build_req_id: fragment("coalesce(nullif(?::text, ''), '')", t.build_request_id),
        old_jobs: fragment("?->?->?", fragment("coalesce(?, '{\"build\":{\"jobs\":[]}}'::jsonb)", t.description), "build", "jobs"),
        new_jobs: fragment("?->?->?", fragment("coalesce(?, '{\"task\":{\"jobs\":[]}}'::jsonb)", t.description), "task", "jobs"),
        error_description: b.error_description
      })
  end

  @doc """
  Finds block by block_id
  """
  def get_by_id(id) do
      Blocks |> where(block_id: ^id) |> Repo.one()
      |> return_tuple(id)
    rescue
      e -> {:error, e}
  end

  @doc """
  Preload BlockRequest
  """
  def preload_request(block) do
    block |> Repo.preload([:block_requests])
  end

  # Utility

  defp return_tuple(nil, block_id), do: {:error, {:block_not_found, block_id}}
  defp return_tuple(value, _),     do: {:ok, value}
end
