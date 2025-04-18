defmodule PublicAPI.Schemas.Stages.Connection do
  @moduledoc """
  Schema for a stage connection
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.Connection",
    type: :object,
    description: "A stage connection contains details about sources / stages with filters",
    properties: %{
      type: %Schema{
        type: :string,
        enum: ~w(STAGE EVENT_SOURCE),
        description: "The type of connection"
      },
      name: %Schema{
        type: :string,
        description: "The name of the connection source"
      },
      filter_operator: %Schema{
        type: :string,
        enum: ~w(AND OR),
        description: "The operator used to combine filters"
      },
      filters: %Schema{
        type: :array,
        items: PublicAPI.Schemas.Stages.ConnectionFilter.schema()
      }
    }
  })
end
