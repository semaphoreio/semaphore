defmodule Zebra.Apis.InternalJobApi.Validator do
  @default_job_priority 50
  # in seconds
  @default_job_execution_time_limit 24 * 60 * 60
  # in minutes
  @max_job_execution_time_limit 24 * 60

  def validate_job(job) do
    with :ok <- validate_project_id(job.project_id),
         :ok <- validate_job_name(job.name),
         :ok <- validate_commands(job.spec.commands),
         :ok <- validate_machine_type(job.machine_type),
         {:ok, job} <- validate_priority(job, job.priority),
         {:ok, job} <- validate_time_limit(job, job.execution_time_limit) do
      {:ok, job}
    else
      error_message -> {:error, :validation, error_message}
    end
  end

  defp validate_project_id(project_id) do
    case UUID.info(project_id) do
      {:ok, _info} -> :ok
      _error -> "Invalid parameter 'project_id' - must be a valid UUID."
    end
  end

  defp validate_job_name(name) when is_binary(name) and name != "", do: :ok

  defp validate_job_name(_name) do
    "The 'job_name' field value must be a non-empty string."
  end

  defp validate_commands(cmds) when is_list(cmds) and cmds != [], do: :ok

  defp validate_commands(_cmds) do
    "The 'commands' list must contain at least one command."
  end

  defp validate_machine_type(type) when is_binary(type) and type != "", do: :ok

  defp validate_machine_type(_type) do
    "The 'agent -> machine ->type' field value must be a non-empty string."
  end

  defp validate_priority(job, value) when value >= 0 and value <= 100, do: {:ok, job}

  defp validate_priority(job, _) do
    {:ok, Map.put(job, :priority, @default_job_priority)}
  end

  # value of execution_time_limit is received in minutes and it is stored in seconds
  defp validate_time_limit(job, val) when val > 0 and val <= @max_job_execution_time_limit do
    {:ok, Map.put(job, :execution_time_limit, val * 60)}
  end

  defp validate_time_limit(job, _) do
    {:ok, Map.put(job, :execution_time_limit, @default_job_execution_time_limit)}
  end
end
