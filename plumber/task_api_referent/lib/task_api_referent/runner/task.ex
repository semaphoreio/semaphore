defmodule TaskApiReferent.Runner.Task do
  @moduledoc """
  Module that executes tasks, task's jobs and job's commands
  If command is invalid, then job has FAILED
  If job has FAILED, then task has FAILED
  Jobs should be executed asynchronously, and commands within them should be executed sequentially
  """


  alias TaskApiReferent.Runner
  alias TaskApiReferent.Service
  alias TaskApiReferent.Initializator, as: Init

  @doc "Initializes task data, starts async job runners."
  def start(params, task_id) do
    with {:ok, jobs_ids} <- Init.Task.init(params, task_id),
          _resp          <- spawn(__MODULE__, :run, [jobs_ids, task_id])
    do
      Service.Task.get_description(task_id)
    else
      {:error, message} ->
        set_status(:error, message, task_id)
    end
  end

  @doc """
  Starts asynchronous execution of Jobs and waits for them to finish executing all Commands.
  Sets Taks's status when all Jobs are executed.
  """
  def run(jobs_ids, task_id) do
    with jobs_ex_task <- Task.async(Runner.Job, :execute, [jobs_ids]),
         # max wait time for all Jobs is set to 50 sec
         jobs_results <- Task.await(jobs_ex_task, 50_000)
    do
      set_status(jobs_results, task_id)
    end
  end

  # Sets an appropriate task status depending on the execution results of all jobs
  defp set_status(job_results, task_id) when is_list(job_results) do
    Service.Task.set_property(task_id, :state, :FINISHED)
    cond do
      Enum.member?(job_results, :error) == true
        -> Service.Task.set_property(task_id, :result, :FAILED)

      Enum.member?(job_results, :stop) == true
        -> Service.Task.set_property(task_id, :result, :STOPPED)

      true -> Service.Task.set_property(task_id, :result, :PASSED)
    end
  end
  defp set_status(:error, error_msg, task_id) do
      Service.Task.set_property(task_id, :state, :FINISHED)
      Service.Task.set_property(task_id, :result, :FAILED)
      Service.Task.set_property(task_id, :error_msg, error_msg)
  end
end
