defmodule TaskApiReferent.Initializator.Task do
  @moduledoc """
  Initializes Task in Task Agent
  """

  alias TaskApiReferent.Service
  alias TaskApiReferent.Initializator, as: Init

  # Initialization of whole Task Struct
  def init(params, task_id) do
    with jobs <- Map.get(params, :jobs),
         {:ok, jobs_ids} <- Init.Job.init_jobs(jobs),
         task_state <- form_task_state(params, task_id, jobs_ids)
    do
      Service.Task.set(task_id, task_state)
      {:ok, jobs_ids}
    else
      _ ->
        {:error, "Task initialization failed."}
    end
  end

  defp form_task_state(params, task_id, jobs_ids) do
    %{
      id: task_id,
      request_token: params.request_token,
      ppl_id: params.ppl_id,
      wf_id: params.wf_id,
      state: :RUNNING,
      result: :FAILED,
      jobs: jobs_ids
    }
  end
end
