defmodule PublicAPI.Schemas.Stages.ConnectionDataFilter do
  @moduledoc """
  Schema for a stage connection data filter
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.ConnectionDataFilter",
    type: :object,
    nullable: true,
    description:
      "A stage connection data filter uses the data from the event to control if the event should or not enter the stage queue",
    properties: %{
      expression: %Schema{
        type: :string,
        description: "The data filter expression"
      }
    }
  })
end
