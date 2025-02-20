defmodule PublicAPI.Schemas.Tasks.Spec do
  @moduledoc """
  Schema for the Task Specification entity
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Spec",
    description: "Task Specification",
    type: :object,
    properties: %{
      name: %Schema{type: :string, example: "Periodic task"},
      description: %Schema{type: :string, example: "Periodic task description"},
      branch: %Schema{type: :string, example: "master"},
      pipeline_file: %Schema{type: :string, example: "pipeline.yml"},
      cron_schedule: %Schema{type: :string, example: "0 0 * * *"},
      paused: %Schema{type: :boolean, example: false},
      parameters: %Schema{type: :array, items: PublicAPI.Schemas.Tasks.Parameter.schema()}
    },
    required: [:name, :branch, :pipeline_file]
  })
end
