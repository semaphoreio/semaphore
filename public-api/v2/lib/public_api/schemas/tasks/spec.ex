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
      reference: %Schema{
        type: :object,
        description: "Git reference for the task",
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
      pipeline_file: %Schema{type: :string, example: "pipeline.yml"},
      cron_schedule: %Schema{type: :string, example: "0 0 * * *"},
      paused: %Schema{type: :boolean, example: false},
      parameters: %Schema{type: :array, items: PublicAPI.Schemas.Tasks.Parameter.schema()},
      commit_status: %Schema{
        type: :string,
        enum: ["follow_project", "always", "never"],
        description:
          "Whether pipelines started by this task submit commit statuses. follow_project defers to the project settings. Defaults to follow_project on create; omitted on update, the stored value is kept."
      }
    },
    required: [:name, :reference, :pipeline_file]
  })
end
