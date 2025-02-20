defmodule PublicAPI.Schemas.Workflows.Schedule do
  @moduledoc """
  Schema for the request of the Workflows.Schedule operation.
  """
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Workflows.ScheduleParameters",
    description: "Workflow schedule parameters",
    type: :object,
    properties: %{
      project_id: %Schema{
        type: :string,
        format: :uuid,
        description: "Id of the project to schedule the workflow in."
      },
      reference: %Schema{
        type: :string,
        description: "git reference for the desired branch, tag, or pull request",
        example: "refs/tags/v1.0"
      },
      commit_sha: %Schema{type: :string, description: "Commit sha of the desired commit."},
      pipeline_file: %Schema{
        type: :string,
        description:
          "he path within the repository to the YAML file that contains the pipeline definition",
        default: ".semaphore/semaphore.yml"
      }
    },
    required: [:project_id, :reference]
  })
end
