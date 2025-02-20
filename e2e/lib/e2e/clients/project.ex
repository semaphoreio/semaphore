defmodule E2E.Clients.Project do
  @moduledoc """
  Client for managing Semaphore projects.
  """

  @api_endpoint "api/v1alpha/projects"

  require Logger
  alias E2E.Clients.Common
  alias E2E.Models.Project, as: ProjectModel

  @doc """
  Creates a new project with the specified configuration.

  ## Parameters
    - opts: Keyword list of options
      - :name - Project name (required)
      - :repository_url - Git repository URL (required)
      - :tasks - List of task configurations (optional)
      - :visibility - Project visibility (optional, defaults to "private")
      - :pipeline_file - Pipeline file path (optional, defaults to ".semaphore/semaphore.yml")
      - :integration_type - Repository integration type (optional, defaults to "github_app")
      - :run_on - List of triggers to run on (optional, defaults to ["tags", "branches"])

  Returns {:ok, project} on success, {:error, reason} on failure.
  """
  def create(opts \\ []) do
    project = ProjectModel.new(opts)
    body = ProjectModel.to_api_payload(project)

    case Common.post(@api_endpoint, body) do
      {:ok, response} ->
        case response.status_code do
          200 ->
            {:ok, Jason.decode!(response.body)}

          status ->
            Logger.error("Error creating project: #{status} - #{response.body}")
            {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end

  @doc """
  Lists all projects.

  Returns {:ok, projects} on success, {:error, reason} on failure.
  """
  def list do
    case Common.get(@api_endpoint) do
      {:ok, response} ->
        case response.status_code do
          200 -> {:ok, Jason.decode!(response.body)}
          status -> {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end

  @doc """
  Retrieves details of a project by its name.

  Returns {:ok, project} on success, {:error, reason} on failure.
  """
  def get(project_name) do
    api_endpoint = "#{@api_endpoint}/#{project_name}"

    case Common.get(api_endpoint) do
      {:ok, response} ->
        case response.status_code do
          200 -> {:ok, Jason.decode!(response.body)}
          404 -> {:error, :not_found}
          status -> {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end

  @doc """
  Updates a project with the complete project configuration.

  ## Parameters
    - project_id: The ID of the project to update (from project["metadata"]["id"])
    - project: Complete project configuration map. This should be the full project map
              with any desired modifications, not just the fields to update.

  ## Example
      # Get the current project
      {:ok, project} = Project.get(project_name)
      project_id = project["metadata"]["id"]

      # Update the project configuration
      updated_project = put_in(project, ["spec", "visibility"], "private")
      {:ok, updated} = Project.update(project_id, updated_project)

  Returns {:ok, project} on success, {:error, reason} on failure.
  """
  @spec update(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def update(project_id, project) do
    api_endpoint = "#{@api_endpoint}/#{project_id}"

    case Common.patch(api_endpoint, project) do
      {:ok, response} ->
        case response.status_code do
          200 -> {:ok, Jason.decode!(response.body)}
          status -> {:error, %{status: status, body: Jason.decode!(response.body)}}
        end

      error ->
        error
    end
  end

  @doc """
  Deletes a project by its name.

  Returns :ok on success, {:error, reason} on failure.
  """
  def delete(project_name) do
    api_endpoint = "#{@api_endpoint}/#{project_name}"

    case Common.delete(api_endpoint) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
