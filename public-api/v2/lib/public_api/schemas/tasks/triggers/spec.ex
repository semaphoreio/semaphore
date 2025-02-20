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
      branch: %Schema{type: :string, example: "master"},
      pipeline_file: %Schema{type: :string, example: ".semaphore/semaphore.yml"},
      parameters: %Schema{
        type: :array,
        items: PublicAPI.Schemas.Tasks.Triggers.Parameter.schema()
      }
    },
    required: []
  })
end
