defmodule PublicAPI.Schemas.Common.SimpleCanvas do
  @moduledoc """
  Schema for a project
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SimpleCanvas",
    type: :object,
    description: "Simple Canvas object",
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
      name: PublicAPI.Schemas.Common.NullableName.schema()
    }
  })
end
