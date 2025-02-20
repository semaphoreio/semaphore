defmodule TaskApiReferent.Service.Job do
  @moduledoc """
  Service Layer delegating calls to the JobAgent
  """

  alias TaskApiReferent.Agent

  @doc "Gets a Job's state from the Job Agent"
  def get(job_id) do
    Agent.Job.get(job_id)
  end

  @doc "Sets the Job state in Job Agent"
  def set(job_id, state) do
    Agent.Job.set(job_id, state)
  end

  @doc "Sets the property value in Job's state Map"
  def set_property(job_id, property_name, property_value) do
    with {:ok, job}  <- get(job_id),
         updated_job <- Map.put(job, property_name, property_value),
    do: set(job_id, updated_job)
  end

  @doc "Gets one of the properties from Job's state Map"
  def get_property(job_id, property_name) do
    with {:ok, job}     <- get(job_id),
         property_value <- Map.get(job, property_name),
    do: {:ok, property_value}
  end

  @doc "Adds property_value into the Job's property_name"
  def add_to_property(job_id, property_name, property_value) do
    with {:ok, list}  <- get_property(job_id, property_name),
         updated_list <- list ++ [property_value],
    do: set_property(job_id, property_name, updated_list)
  end
end
