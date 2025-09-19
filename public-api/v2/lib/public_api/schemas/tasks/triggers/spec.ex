defmodule PublicAPI.Schemas.Tasks.Triggers.Spec do
  @moduledoc """
  Schema for the request body of Tasks.Trigger operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Trigger.Spec",
    description: "Task Trigger specification",
    type: :object,
    properties: %{
      reference: %Schema{
        type: :object,
        description: "Git reference to trigger the task with",
        properties: %{
          type: %Schema{
            type: :string,
            enum: ["branch", "tag"],
            description: "Type of git reference",
            example: "branch"
          },
          name: %Schema{
            type: :string,
            description: "Name of the branch or tag",
            example: "master"
          }
        },
        required: [:type, :name]
      },
      branch: %Schema{
        type: :string,
        example: "master",
        description: "Legacy branch parameter - use reference.name instead",
        deprecated: true
      },
      pipeline_file: %Schema{type: :string, example: ".semaphore/semaphore.yml"},
      parameters: %Schema{
        type: :array,
        items: PublicAPI.Schemas.Tasks.Triggers.Parameter.schema()
      }
    },
    required: []
  })
end
