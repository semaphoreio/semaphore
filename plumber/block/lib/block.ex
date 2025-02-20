defmodule Block do
  @moduledoc """
  Entrypoint module for Block application.
  """

  import Ecto.Query

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.TasksQueries
  alias Block.Blocks.Model.{Blocks, BlocksQueries}
  alias Block.EctoRepo, as: Repo
  alias Util.{ToTuple, Metrics}
  alias Ecto.Multi
  alias Block.Blocks.STMHandler.InitializingState, as: BlockInitializingState
  alias Block.Blocks.STMHandler.RunningState, as: BlockRunningState

  @version "0.1.0"

  @doc """
  Returns version of  Block application
  """
  def version, do: @version

  @doc """
  Duplicates BlockRequest, Block and Task db rows for passed block/task
  with new ids and returns new block_id to caller.
  """
  def duplicate(block_id, new_ppl_id) do
    Metrics.benchmark("Block.duplicate", fn ->
      case duplicate_data(block_id, new_ppl_id) do
        {:ok, %{duplicate_block: block}} -> {:ok, block.block_id}
        {:error, _e} = error -> error
        error -> {:error, error}
      end
    end)
  end

  defp duplicate_data(block_id, new_ppl_id) do
    Multi.new()
    |> Multi.run(:duplicate_block_request, fn _, _ ->
      BlockRequestsQueries.duplicate(block_id, new_ppl_id) end)
    |> Multi.run(:duplicate_block, fn _, %{duplicate_block_request: new_blk_req} ->
      BlocksQueries.duplicate(block_id, new_blk_req.id) end)
    |> Multi.run(:duplicate_task, fn _, %{duplicate_block_request: new_blk_req} ->
      TasksQueries.duplicate(block_id, new_blk_req.id) end)
    |> Repo.transaction()
  end

  @doc """
  Entrypoint for schedule running of block from ppl application.
  Params -
    - request - Map which contains fields:
      - ppl_id: Pipeline's id
      - pple_block_index: Index of block in pipeline's 'blocks' field
      - hook_id: Pipeline's identifier from Semaphore front
      - request_args: map with informations about ppl request (service, repo etc.)
      - source_args: map with informations from source that triggered pipeline
      - version: version of pipeline
      - definition: map which contains block's definition (build and include fields)
  """
  def schedule(request) do
    Metrics.benchmark("Block.schedule", fn ->
      with {:ok, blk_req} <- BlockRequestsQueries.insert_request(request),
           {:ok, _blk}    <- BlocksQueries.insert(blk_req)
      do
        fn query -> query |> where(block_id: ^blk_req.id) end
        |> Block.Blocks.STMHandler.InitializingState.execute_now_with_predicate()
        {:ok, blk_req.id}
      end
    end)
  end

  @doc """
  Entrypoint for describing block from ppl application.
  Params:
    - block_id: Block's id
  """
  def describe(block_id) do
    Metrics.benchmark("Block.describe", fn ->
      with {:ok, blk}         <- BlocksQueries.get_by_id(block_id),
           task_resp          <- TasksQueries.get_by_id(block_id),
      do: form_description(task_resp, blk)
    end)
  end

  defp form_description({:ok, task}, blk) do
    %{
      block_id: blk.block_id,
      build_req_id: task.build_request_id,
      jobs: jobs_desc(task),
      error_description: blk.error_description
    } |> ToTuple.ok()
  end
  defp form_description(_blk_bld_not_found, blk) do
    %{
      block_id: blk.block_id,
      build_req_id: "",
      error_description: blk.error_description
    } |> ToTuple.ok()
  end

  defp jobs_desc(task) do
    task
    |> Map.from_struct()
    |> take_jobs()
    |> (fn jobs -> jobs || [] end).()
    |> Enum.map(fn job -> job_to_old_format(job) end)
  end
  defp take_jobs(%{description: %{"task" => %{"jobs" => jobs}}}), do: jobs
  defp take_jobs(%{description: %{"build" => %{"jobs" => jobs}}}), do: jobs
  defp take_jobs(_), do: []

  defp job_to_old_format(job) do
    job
    |> job_to_old_format_(job["status"])
    |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)
  end

  # new format, should be transformed
  defp job_to_old_format_(job, nil) do
    job
    |> Map.put("status", job["state"])
    |> Map.put("job_id", job["id"])
    |> Map.drop(["state", "id"])
  end
  # old format, return as is
  defp job_to_old_format_(job, _status), do: job

  @doc """
  Entrypoint for listing all blocks from pipeline with given ppl_id from ppl application.
  Params:
    - ppl_id: id od pipeline which blocks should be returned
  """
  def list (ppl_id) do
    Metrics.benchmark("Block.list", fn ->
      with {:ok, raw_blocks} <- BlocksQueries.list(ppl_id),
      do: transform_raw_blocks(raw_blocks)
    end)
  end

  defp transform_raw_blocks(raw_blocks) do
    raw_blocks |> Enum.map(fn raw_block -> transform_jobs(raw_block) end) |> ToTuple.ok()
  end

  defp transform_jobs(block) do
    block
    |> get_jobs()
    |> Enum.map(fn job -> job_to_old_format(job) end)
    |> reverse_map_put(:jobs, block)
    |> Map.drop([:old_jobs, :new_jobs])
  end

  defp get_jobs(%{old_jobs: old, new_jobs: new}) when is_nil(old) and is_nil(new), do: []
  defp get_jobs(%{old_jobs: old, new_jobs: new}) when old == [] and new == [], do: []
  defp get_jobs(%{old_jobs: old, new_jobs: new}) when is_nil(old), do: new
  defp get_jobs(%{old_jobs: old, new_jobs: new}) when is_nil(new), do: old

  defp reverse_map_put(v, k, map), do: Map.put(map, k, v)

  @doc """
  Entrypoint for getting block status from ppl application.
  Params:
    - block_id: Block's id
  """
  def status(block_id) do
    Metrics.benchmark("Block.status", fn ->
      with {:ok, blk}  <- BlocksQueries.get_by_id(block_id),
      do: {:ok, %{state: blk.state, result: blk.result, result_reason: blk.result_reason,
                  inserted_at: blk.inserted_at |> DateTime.from_naive!("Etc/UTC"),
                  updated_at: blk.updated_at |> DateTime.from_naive!("Etc/UTC")}}
    end)
  end

  @doc """
  Entrypoint for terminating block's execution from ppl application.
  Params:
    - block_id: Block's id
  """
  def terminate(block_id) do
    Metrics.benchmark("Block.terminate", fn ->
      with {:ok, blk}  <- BlocksQueries.get_by_id(block_id),
      do: terminate_block(blk, blk.state)
    end)
  end

  defp terminate_block(_blk, "stopping"), do: {:ok, "Block termination started."}
  defp terminate_block(_blk, "done"), do: {:ok, "Block termination started."}
  defp terminate_block(blk, _state) do
    blk
    |> Blocks.changeset(termination_params())
    |> Repo.update()
    |> trigger_loopers()
    |> respond_terminated()
  end

  defp termination_params() do
    %{terminate_request: "stop", terminate_request_desc: "API call"}
  end

  defp trigger_loopers({:ok, block}) do
    import Ecto.Query

    query_fun = fn query -> query |> where(block_id: ^block.block_id) end

    query_fun |> BlockInitializingState.execute_now_with_predicate()
    query_fun |> BlockRunningState.execute_now_with_predicate()
  end
  defp trigger_loopers(error), do: error

  defp respond_terminated(:ok), do: {:ok, "Block termination started."}
  defp respond_terminated(e = {:error, _}), do: e
  defp respond_terminated(error), do: {:error, error}

  @doc """
  Deletes all blocks from pipeline with given ppl_id and all related structures from DB.
  """
  def delete_blocks_from_ppl(ppl_id) do
    Metrics.benchmark("Block.delete_blocks", fn ->
      with {:ok, n} <- BlockRequestsQueries.delete_blocks_from_ppl(ppl_id),
      do: {:ok, "Deleted #{n} blocks successfully."}
    end)
  end
end
