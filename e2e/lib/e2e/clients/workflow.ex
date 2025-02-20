defmodule E2E.Clients.Workflow do
  @api_endpoint "api/v1alpha/plumber-workflows"

  alias E2E.Clients.Common

  @doc """
  Triggers a new workflow.
  Returns {:ok, workflow} on success, {:error, reason} on failure.

  Required params:
  - project_id: ID of a project
  - reference: git reference (e.g. refs/heads/master, refs/tags/v1.0)
  Optional:
  - commit_sha: Commit sha of the desired commit
  - pipeline_file: Path to pipeline definition (default: .semaphore/semaphore.yml)
  """
  def trigger(params) do
    case Common.post(@api_endpoint, params) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, workflow} -> {:ok, workflow}
              {:error, _} -> {:error, "Invalid JSON response"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a specific workflow by ID.
  Returns {:ok, workflow} on success, {:error, reason} on failure.
  """
  def get(workflow_id) do
    case Common.get("#{@api_endpoint}/#{workflow_id}") do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, workflow} -> {:ok, workflow}
              {:error, _} -> {:error, "Invalid JSON response"}
            end

          404 ->
            {:error, :not_found}

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists workflows for a project, with optional filtering.
  Returns {:ok, workflows} on success, {:error, reason} on failure.

  Required params:
  - project_id: ID of a project

  Optional:
  - branch_name: Name of branch to filter by
  """
  def list_by_project(project_id, filters \\ %{}) do
    query_params =
      Map.merge(%{"project_id" => project_id}, filters)
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")

    case Common.get("#{@api_endpoint}?#{query_params}") do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, workflows} -> {:ok, workflows}
              {:error, _} -> {:error, "Invalid JSON response"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reruns a workflow.
  Returns {:ok, workflow} on success, {:error, reason} on failure.

  Required:
  - workflow_id: ID of the workflow to rerun
  - request_token: Idempotency token (can be any string)
  """
  def rerun(workflow_id) do
    case Common.post(
           "#{@api_endpoint}/#{workflow_id}/reschedule?request_token=#{UUID.uuid4()}",
           %{}
         ) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, workflow} -> {:ok, workflow}
              {:error, _} -> {:error, "Invalid JSON response"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stops a running workflow.
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def stop(workflow_id) do
    case Common.post("#{@api_endpoint}/#{workflow_id}/terminate", %{}) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 -> {:ok, response.body}
          _ -> {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
