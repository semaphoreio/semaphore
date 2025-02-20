defmodule TaskApiReferent.Agent.Task do
  @moduledoc """
  Elixir Agent used to persist state of each task

  example:
    %{task_id:
      %{
        id: UUID,
        ppl_id: UUID,
        wf_id: UUID,
        request_token: UUID,
        state: :FINISHED,
        result: :PASSED,
        jobs: [job_id1, job_id2, ...]
      }
    }
  """

  use Agent

  @doc "Starts an agent and initializes state map"
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    Agent.start_link(fn -> {%{}, %{}} end, opts)
  end

  @doc "Gets a Task's state from the Agent's state Map"
  def get(task_id) do
    Agent.get(__MODULE__, fn {tasks, _req_tokens_to_ids} ->
      case Map.get(tasks, task_id) do
        nil -> {:error, "'task_id' parameter that you provided doesn't match any task."}
        task -> {:ok, task}
      end
    end)
  end

  @doc "Gets an id of task for given request_token"
  def get_task_id(request_token) do
    Agent.get(__MODULE__, fn {_tasks, req_tokens_to_ids} ->
      case Map.get(req_tokens_to_ids, request_token) do
        nil -> {:error, "'request_token' parameter that you provided doesn't match any task."}
        task_id -> {:ok, task_id}
      end
    end)
  end

  @doc "Sets the Task state in Agent's State Map"
  def set(task_id, task) do
    Agent.get_and_update(__MODULE__, fn {tasks, req_tokens_to_ids} ->
      new_tasks = Map.put(tasks, task_id, task)
      new_req_tokens = req_tokens_to_ids |> Map.put(task.request_token, task_id)
      {{:ok, task}, {new_tasks, new_req_tokens}}
    end)
  end
end
