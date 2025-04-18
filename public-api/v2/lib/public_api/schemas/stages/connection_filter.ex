defmodule PublicAPI.Schemas.Stages.ConnectionFilter do
  @moduledoc """
  Schema for a stage connection filter
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Stages.ConnectionFilter",
    type: :object,
    nullable: true,
    description:
      "A stage connection filter contains details of how to discard events from source before they enter the stage queue",
    properties: %{
      type: %Schema{
        type: :string,
        enum: ~w(DATA),
        description: "The type of filter"
      },
      data: PublicAPI.Schemas.Stages.ConnectionDataFilter.schema()
    }
  })
end
