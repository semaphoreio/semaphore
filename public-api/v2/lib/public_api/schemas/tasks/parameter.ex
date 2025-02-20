defmodule PublicAPI.Schemas.Tasks.Parameter do
  @moduledoc """
  Schema for the Task Parameter object value
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Task.Parameter",
    description: "Task Parameter",
    type: :object,
    properties: %{
      name: %Schema{type: :string, pattern: "^[A-Z_]{1,}[A-Z0-9_]*$", example: "PARAM_NAME"},
      description: %Schema{type: :string, example: "Parameter description"},
      required: %Schema{type: :boolean, example: true},
      default_value: %Schema{type: :string, example: "Default value"},
      options: %Schema{type: :array, items: %Schema{type: :string}}
    },
    required: [:name, :required]
  })
end
