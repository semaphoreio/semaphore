defmodule Block.Tasks.Model.TasksQueries do
  @moduledoc """
  Tasks Queries
  Operations on Task type

  'pending' - initial task's state.
  Ready to be scheduled on the Semaphore.
  From 'pending' task transitions to 'running' or 'done'.

  'running'
  Task is still in progress.
  The request will be fetched by some looper later and checked again.
  From 'running' task transitions to 'stopping' or 'done'.

  'stopping'
  Task's termination is started, waiting for it to be finished on Semaphore.
  From 'stopping' task transitions to 'done'.

  'done' - terminal state
  Task's execution is done and execution status is saved in 'result' field.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Block.EctoRepo, as: Repo
  alias Block.Tasks.Model.Tasks
  alias Util.ToTuple

  def multi_insert(multi, blk_req) do
    params = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:build_request_id, UUID.uuid4())

    changeset = Tasks.changeset(%Tasks{}, params)
    Multi.insert(multi, :task, changeset)
  end

  @doc """
  Duplicates passed Tasks and changes block_id to new value.
  Used in partial rebuilding to avoid reruning passed block builds.
  """
  def duplicate(block_id, new_block_id) do
    block_id |> get_by_id() |> change_ids(new_block_id) |> duplicate()
  end

  defp change_ids({:ok, blk_bld = %{state: "done", result: "passed"}}, new_block_id) do
    blk_bld
    |> Map.from_struct()
    |> Map.drop([:id, :block_id])
    |> Map.put(:block_id, new_block_id)
    |> ToTuple.ok()
  end
  defp change_ids({:ok, %{block_id: id}}, _new_block_id),
    do: "Can not dupplicate task for block #{id} because it's result is not 'passed'." |> ToTuple.error()
  defp change_ids(error, _new_block_id), do: error

  defp duplicate({:ok, params}) do
    try do
      %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
    rescue
      e -> {:error, e}
    end
  end
  defp duplicate(error), do: error

  def terminate(task, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    task
    |> Tasks.changeset(params)
    |> Repo.update()
  end

  def get_by_id(id) do
      Tasks |> where(block_id: ^id) |> Repo.one()
      |> return_tuple("Task for block with id: #{id} not found")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
