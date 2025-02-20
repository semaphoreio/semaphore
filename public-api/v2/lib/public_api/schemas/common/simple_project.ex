defmodule PublicAPI.Schemas.Common.SimpleProject do
  @moduledoc """
  Schema for a project
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SimpleProject",
    type: :object,
    description: "Simple Project object",
    properties: %{
      id: PublicAPI.Schemas.Common.ResourceId.schema(),
      name: PublicAPI.Schemas.Common.NullableName.schema()
    }
  })
end
