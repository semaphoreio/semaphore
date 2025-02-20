defmodule PublicAPI.Schemas.Tasks.Triggers.Metadata do
  @moduledoc """
  Schema for the request body of Tasks.Trigger operation.
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Trigger.Metadata",
    description: "Task Trigger Metadata",
    type: :object,
    properties: %{
      workflow_id: PublicAPI.Schemas.Common.id("Workflow"),
      status: %Schema{type: :string, example: "passed"},
      triggered_by: PublicAPI.Schemas.Common.User.schema(),
      triggered_at: timestamp(),
      scheduled_at: timestamp()
    },
    required: []
  })
end
