defmodule PublicAPI.Schemas.Stages.Tag do
  @moduledoc """
  Schema for a stage event
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.Tag",
    type: :object,
    required: [:name, :value, :state],
    properties: %{
      name: %Schema{
        type: :string
      },
      value: %Schema{
        type: :string
      },
      state: %Schema{
        type: :string,
        enum: ~w(UNKNOWN HEALTHY UNHEALTHY)
      }
    }
  })
end
