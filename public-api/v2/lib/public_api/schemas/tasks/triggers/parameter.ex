defmodule PublicAPI.Schemas.Tasks.Triggers.Parameter do
  @moduledoc """
  Schema for the Task Trigger Parameter object value
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Trigger.Parameter",
    description: "Task Trigger Parameter",
    type: :object,
    properties: %{
      name: %Schema{type: :string, example: "Parameter name"},
      value: %Schema{type: :string, example: "Parameter value"}
    },
    required: [:name, :value]
  })
end
