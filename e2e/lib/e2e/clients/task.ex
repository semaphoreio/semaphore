defmodule E2E.Clients.Task do
  @moduledoc """
  Client for managing Semaphore tasks.
  """

  @api_endpoint "api/v1alpha/tasks"

  require Logger
  alias E2E.Clients.Common

  @doc """
  Triggers an immediate run of a task.

  ## Parameters
    - task_id: ID of the task to run

  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def run_now(task_id) do
    endpoint = "#{@api_endpoint}/#{task_id}/run_now"

    case Common.post(endpoint) do
      {:ok, response} ->
        case response.status_code do
          200 ->
            {:ok, Jason.decode!(response.body)}

          status ->
            Logger.error("Error running task: #{status} - #{response.body}")
            {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end

  @doc """
  Lists all tasks for a project.

  ## Parameters
    - project_id: ID of the project

  Returns {:ok, tasks} on success, {:error, reason} on failure.
  """
  def list(project_id) do
    endpoint = "#{@api_endpoint}?project_id=#{project_id}"

    case Common.get(endpoint) do
      {:ok, response} ->
        case response.status_code do
          200 ->
            {:ok, Jason.decode!(response.body)}

          status ->
            Logger.error("Error listing tasks: #{status} - #{response.body}")
            {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end
end
