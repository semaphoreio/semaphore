defmodule TaskApiReferent.Service.Task do
  @moduledoc """
  Service Layer delegating calls to the TaskAgent
  """

  alias TaskApiReferent.Agent

  @doc "Gets a Task's state from the Task Agent"
  def get(task_id) do
    Agent.Task.get(task_id)
  end

  @doc "Gets an id of task for given request_token"
  def get_task_id(request_token) do
    Agent.Task.get_task_id(request_token)
  end

  @doc "Sets the Task state in Task Agent"
  def set(task_id, state) do
    Agent.Task.set(task_id, state)
  end

  @doc "Sets one of the properties in Task's state Map"
  def set_property(task_id, property_name, property_value) do
    with {:ok, task}  <- get(task_id),
         updated_task <- Map.put(task, property_name, property_value),
    do: set(task_id, updated_task)
  end

  @doc "Gets one of the properties in Task's Map"
  def get_property(task_id, property_name) do
    with {:ok, task}   <- get(task_id),
         property_value <- Map.get(task, property_name),
    do: {:ok, property_value}
  end

  @doc "Adds property_value into the Task's property_name List"
  def add_to_property(task_id, property_name, property_value) do
    with {:ok, list}  <- get_property(task_id, property_name),
         updated_list <- list ++ [property_value],
    do: set_property(task_id, property_name, updated_list)
  end

  @doc "Returns Task's description"
  def get_description(task_id) do
    with {:ok, task} <- Agent.Task.get(task_id),
         task_desc   <- form_description(task),
    do: {:ok, task_desc}
  end

  defp form_description(task) do
    jobs =
      task.jobs |> Enum.map(fn job_id ->
        {:ok, job} = Agent.Job.get(job_id)
        job
       end)
    task
    |> Map.put(:jobs, jobs)
    |> Map.put(:created_at, DateTime.utc_now())
    |> Map.put(:finished_at, DateTime.utc_now())
  end
end
