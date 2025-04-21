defmodule PublicAPI.Schemas.Stages.RunTemplateSemaphore do
  @moduledoc """
  Schema for a semaphore run template
  """
  alias ElixirLS.LanguageServer.Plugins.Ecto.Schema
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.RunTemplateSemaphore",
    type: :object,
    nullable: true,
    description: "A run template for triggering Semaphore workflows and tasks",
    required: [:project_id, :branch, :pipeline_file],
    properties: %{
      project_id: PublicAPI.Schemas.Common.ResourceId.schema(),
      task_id: %Schema{
        title: "Task Id",
        type: :string,
        description: "If this is set, a task will be triggered instead of a simple workflow",
        format: :uuid,
        nullable: true,
        example: UUID.uuid4()
      },
      branch: %Schema{
        type: :string,
        description: "The branch to use"
      },
      pipeline_file: %Schema{
        type: :string,
        description: "The pipeline file YAML to use"
      },
      parameters: %Schema{
        type: :array,
        default: [],
        items: %Schema{
          type: :object,
          properties: %{
            name: %Schema{
              type: :string,
              description: "The name of the parameter"
            },
            value: %Schema{
              type: :string,
              description: "The value of the parameter"
            }
          }
        }
      }
    }
  })
end
