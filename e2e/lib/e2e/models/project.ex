defmodule E2E.Models.Project do
  @moduledoc """
  Project model for handling project structure and validation.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          repository_url: String.t(),
          tasks: list(map()),
          visibility: String.t(),
          pipeline_file: String.t(),
          integration_type: String.t(),
          run_on: list(String.t())
        }

  defstruct [
    :name,
    :repository_url,
    tasks: [],
    visibility: "private",
    pipeline_file: ".semaphore/semaphore.yml",
    integration_type: "github_app",
    run_on: ["tags", "branches"]
  ]

  @doc """
  Creates a new project struct with the given options.
  """
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Converts a project struct to API payload format.
  """
  def to_api_payload(%__MODULE__{} = project) do
    %{
      "spec" => %{
        "visibility" => project.visibility,
        "tasks" => project.tasks,
        "schedulers" => [],
        "repository" => %{
          "url" => project.repository_url,
          "integration_type" => project.integration_type,
          "status" => %{
            "pipeline_files" => [
              %{
                "path" => project.pipeline_file,
                "level" => "pipeline"
              }
            ]
          },
          "run_on" => project.run_on,
          "pipeline_file" => project.pipeline_file
        }
      },
      "metadata" => %{
        "name" => project.name
      },
      "kind" => "Project",
      "apiVersion" => "v1alpha"
    }
  end

  @doc """
  Creates a task configuration.
  """
  def task(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    branch = Keyword.get(opts, :branch, "master")
    status = Keyword.get(opts, :status, "ACTIVE")
    scheduled = Keyword.get(opts, :scheduled, true)
    pipeline_file = Keyword.get(opts, :pipeline_file, ".semaphore/semaphore.yml")
    description = Keyword.get(opts, :description, "")
    at = Keyword.get(opts, :at, "0 0 * * *")
    parameters = Keyword.get(opts, :parameters, [])

    %{
      "status" => status,
      "scheduled" => scheduled,
      "pipeline_file" => pipeline_file,
      "parameters" => parameters,
      "name" => name,
      "description" => description,
      "branch" => branch,
      "at" => at
    }
  end
end
