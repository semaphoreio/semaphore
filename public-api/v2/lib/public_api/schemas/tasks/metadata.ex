defmodule PublicAPI.Schemas.Tasks.Metadata do
  @moduledoc """
  Schema for the Task Metadata entity
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Metadata",
    description: "Task Metadata",
    type: :object,
    properties: %{
      id: PublicAPI.Schemas.Common.id("Task"),
      project_id: PublicAPI.Schemas.Common.id("Project"),
      scheduled: %Schema{type: :boolean, example: false},
      suspended: %Schema{type: :boolean, example: false},
      updated_by: %{PublicAPI.Schemas.Common.User.schema() | nullable: true},
      paused_by: %{PublicAPI.Schemas.Common.User.schema() | nullable: true},
      inserted_at: timestamp(),
      updated_at: timestamp(),
      paused_at: timestamp()
    },
    required: [:id, :project_id, :suspended, :updated_by, :inserted_at, :updated_at]
  })
end
